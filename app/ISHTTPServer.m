#import "ISHTTPServer.h"
#import "ISPaths.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>
#import <string.h>
#import <stdio.h>
#import <stdlib.h>

#pragma mark - Peticion

@interface ISHTTPRequest : NSObject
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) NSDictionary *params;
@property (nonatomic, assign) unsigned long long contentLength;
@property (nonatomic, assign) BOOL chunked;
@end

@implementation ISHTTPRequest
@end

#pragma mark - Utilidades C

static NSString *ISStatusText(int code) {
    switch (code) {
        case 200: return @"OK";
        case 204: return @"No Content";
        case 206: return @"Partial Content";
        case 301: return @"Moved Permanently";
        case 400: return @"Bad Request";
        case 403: return @"Forbidden";
        case 404: return @"Not Found";
        case 405: return @"Method Not Allowed";
        case 409: return @"Conflict";
        case 413: return @"Payload Too Large";
        case 416: return @"Range Not Satisfiable";
        case 500: return @"Internal Server Error";
        case 507: return @"Insufficient Storage";
        default:  return @"OK";
    }
}

static NSString *ISHTTPDate(void) {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss 'GMT'";
    });
    @synchronized(formatter) {
        return [formatter stringFromDate:[NSDate date]];
    }
}

static BOOL ISWriteAll(int fd, const void *bytes, NSUInteger length) {
    const uint8_t *cursor = (const uint8_t *)bytes;
    NSUInteger remaining = length;
    while (remaining > 0) {
        ssize_t sent = send(fd, cursor, remaining, 0);
        if (sent < 0) {
            if (errno == EINTR) { continue; }
            return NO;
        }
        if (sent == 0) { return NO; }
        cursor += sent;
        remaining -= (NSUInteger)sent;
    }
    return YES;
}

// send() solo vale para sockets: con un descriptor de archivo falla con
// ENOTSOCK y la subida se aborta. Para el disco hace falta write().
static BOOL ISWriteFileAll(int fd, const void *bytes, NSUInteger length) {
    const uint8_t *cursor = (const uint8_t *)bytes;
    NSUInteger remaining = length;
    while (remaining > 0) {
        ssize_t written = write(fd, cursor, remaining);
        if (written < 0) {
            if (errno == EINTR) { continue; }
            return NO;
        }
        if (written == 0) { return NO; }
        cursor += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}

static BOOL ISReceiveMore(int fd, NSMutableData *buffer) {
    uint8_t chunk[65536];
    errno = 0;
    ssize_t count = recv(fd, chunk, sizeof(chunk), 0);
    if (count < 0) { return NO; }
    if (count == 0) {
        errno = EPIPE;  // el otro extremo cerro la conexion
        return NO;
    }
    [buffer appendBytes:chunk length:(NSUInteger)count];
    return YES;
}

static NSString *ISURLDecode(NSString *value) {
    if (!value.length) { return @""; }
    const char *utf8 = [value UTF8String];
    NSUInteger length = strlen(utf8);
    NSMutableData *data = [NSMutableData dataWithCapacity:length];

    for (NSUInteger i = 0; i < length; i++) {
        char c = utf8[i];
        if (c == '+') {
            char space = ' ';
            [data appendBytes:&space length:1];
        } else if (c == '%' && i + 2 < length) {
            char hex[3] = { utf8[i + 1], utf8[i + 2], 0 };
            unsigned int byte = 0;
            if (sscanf(hex, "%2x", &byte) == 1) {
                uint8_t b = (uint8_t)byte;
                [data appendBytes:&b length:1];
                i += 2;
            } else {
                [data appendBytes:&c length:1];
            }
        } else {
            [data appendBytes:&c length:1];
        }
    }

    NSString *decoded = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return decoded ?: value;
}

static NSDictionary *ISParseQuery(NSString *rawQuery) {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (!rawQuery.length) { return params; }
    for (NSString *pair in [rawQuery componentsSeparatedByString:@"&"]) {
        if (!pair.length) { continue; }
        NSRange equals = [pair rangeOfString:@"="];
        if (equals.location == NSNotFound) {
            params[ISURLDecode(pair)] = @"";
        } else {
            NSString *key = [pair substringToIndex:equals.location];
            NSString *value = [pair substringFromIndex:equals.location + 1];
            params[ISURLDecode(key)] = ISURLDecode(value);
        }
    }
    return params;
}

static NSString *ISPercentEncode(NSString *value) {
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    const uint8_t *bytes = data.bytes;
    NSMutableString *out = [NSMutableString stringWithCapacity:data.length];
    for (NSUInteger i = 0; i < data.length; i++) {
        uint8_t b = bytes[i];
        BOOL safe = (b >= 'a' && b <= 'z') || (b >= 'A' && b <= 'Z') ||
                    (b >= '0' && b <= '9') || b == '-' || b == '_' || b == '.' || b == '~';
        if (safe) {
            [out appendFormat:@"%c", (int)b];
        } else {
            [out appendFormat:@"%%%02X", (unsigned int)b];
        }
    }
    return out;
}

#pragma mark - Servidor

@interface ISHTTPServer ()
@property (atomic, assign, readwrite) BOOL running;
@property (atomic, assign, readwrite) uint16_t port;
@property (atomic, assign, readwrite) unsigned long long bytesIn;
@property (atomic, assign, readwrite) unsigned long long bytesOut;
@property (atomic, assign, readwrite) NSUInteger uploadCount;
@property (atomic, assign, readwrite) NSUInteger requestCount;
@end

@implementation ISHTTPServer {
    int _listenFD;
    dispatch_source_t _source;
    dispatch_queue_t _acceptQueue;
    NSInteger _activeConnections;
    NSMutableSet *_clientFDs;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _listenFD = -1;
        _allowDelete = YES;
        _allowUpload = YES;
        _running = NO;
        _activeConnections = 0;
        _clientFDs = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

#pragma mark - Ciclo de vida

- (BOOL)startOnPort:(uint16_t)port error:(NSString **)error {
    if (self.running) { [self stop]; }
    if (port < 1024) { port = 8080; }

    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        if (error) { *error = [NSString stringWithFormat:@"No se pudo crear el socket (%s).", strerror(errno)]; }
        return NO;
    }

    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    address.sin_addr.s_addr = htonl(INADDR_ANY);

    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        if (error) {
            *error = [NSString stringWithFormat:
                      @"No se pudo abrir el puerto %d. Puede que esté ocupado; prueba otro.\n(%s)",
                      (int)port, strerror(errno)];
        }
        close(fd);
        return NO;
    }

    if (listen(fd, 32) < 0) {
        if (error) { *error = [NSString stringWithFormat:@"No se pudo escuchar: %s", strerror(errno)]; }
        close(fd);
        return NO;
    }

    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    _listenFD = fd;
    _acceptQueue = dispatch_queue_create("com.lofturb.isend.accept", DISPATCH_QUEUE_SERIAL);

    __weak typeof(self) weakSelf = self;
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
                                                      (uintptr_t)fd, 0, _acceptQueue);
    dispatch_source_set_event_handler(source, ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) { [strongSelf acceptPendingConnections]; }
    });
    _source = source;
    dispatch_resume(source);

    self.port = port;
    self.running = YES;
    [self notifyActivity];
    return YES;
}

- (void)stop {
    BOOL wasRunning = self.running;
    self.running = NO;

    if (_source) {
        dispatch_source_cancel(_source);
        _source = nil;
    }
    if (_listenFD >= 0) {
        close(_listenFD);
        _listenFD = -1;
    }

    // Desbloquea los hilos que estén esperando datos: si no, siguen ocupando
    // conexiones hasta 20 s y las peticiones nuevas se quedan sin respuesta.
    [self closeActiveConnections];

    if (wasRunning) { [self notifyActivity]; }
}

- (void)closeActiveConnections {
    NSArray *fds = nil;
    @synchronized(self) {
        fds = [_clientFDs allObjects];
        [_clientFDs removeAllObjects];
    }
    for (NSNumber *number in fds) {
        shutdown([number intValue], SHUT_RDWR);
    }
}

- (void)resetCounters {
    self.bytesIn = 0;
    self.bytesOut = 0;
    self.uploadCount = 0;
    self.requestCount = 0;
}

- (void)acceptPendingConnections {
    while (self.running) {
        int client = accept(_listenFD, NULL, NULL);
        if (client < 0) { break; }

        // En BSD/Darwin el socket aceptado hereda O_NONBLOCK del de escucha.
        // Sin esto, recv() devuelve EAGAIN en cuanto el cuerpo de una subida
        // no llega en el mismo bloque que las cabeceras.
        int clientFlags = fcntl(client, F_GETFL, 0);
        if (clientFlags >= 0) {
            fcntl(client, F_SETFL, clientFlags & ~O_NONBLOCK);
        }

        int one = 1;
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
        setsockopt(client, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));

        @synchronized(self) {
            if (_activeConnections >= 32) {
                close(client);
                continue;
            }
            _activeConnections++;
            [_clientFDs addObject:@(client)];
        }

        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf) { [strongSelf serveConnection:client]; }
            }
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                @synchronized(strongSelf) {
                    [strongSelf->_clientFDs removeObject:@(client)];
                    strongSelf->_activeConnections--;
                }
            }
            close(client);
        });
    }
}

- (void)serveConnection:(int)fd {
    struct timeval timeout;
    timeout.tv_sec = 15;
    timeout.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    timeout.tv_sec = 60;
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    NSMutableData *buffer = [NSMutableData dataWithCapacity:16384];
    ISHTTPRequest *request = [self readRequestFrom:fd buffer:buffer];
    if (!request) { return; }

    // Ya hay petición: el cuerpo puede tardar mucho más (un archivo grande).
    timeout.tv_sec = 180;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    self.requestCount = self.requestCount + 1;

    // Ojo: un mensaje a nil devuelve {0,0}, no NSNotFound. Sin el nil explicito
    // se mandaba 100 Continue a todas las peticiones.
    NSString *expect = request.headers[@"expect"];
    if (expect && [expect rangeOfString:@"100-continue"
                                options:NSCaseInsensitiveSearch].location != NSNotFound) {
        const char *cont = "HTTP/1.1 100 Continue\r\n\r\n";
        ISWriteAll(fd, cont, strlen(cont));
    }

    [self dispatchRequest:request fd:fd buffer:buffer];
}

#pragma mark - Lectura de la peticion

- (ISHTTPRequest *)readRequestFrom:(int)fd buffer:(NSMutableData *)buffer {
    static NSData *separator = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        separator = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    });

    NSRange found = [buffer rangeOfData:separator options:0
                                  range:NSMakeRange(0, buffer.length)];
    while (found.location == NSNotFound) {
        if (buffer.length > 65536) { return nil; }
        if (!ISReceiveMore(fd, buffer)) { return nil; }
        found = [buffer rangeOfData:separator options:0
                              range:NSMakeRange(0, buffer.length)];
    }

    NSData *headData = [buffer subdataWithRange:NSMakeRange(0, found.location)];
    [buffer replaceBytesInRange:NSMakeRange(0, found.location + separator.length)
                      withBytes:NULL length:0];

    NSString *text = [[NSString alloc] initWithData:headData
                                           encoding:NSISOLatin1StringEncoding];
    if (!text.length) { return nil; }

    NSArray *lines = [text componentsSeparatedByString:@"\r\n"];
    if (!lines.count) { return nil; }

    NSArray *parts = [lines[0] componentsSeparatedByString:@" "];
    if (parts.count < 2) { return nil; }

    ISHTTPRequest *request = [[ISHTTPRequest alloc] init];
    request.method = [[parts[0] uppercaseString] copy];

    NSString *target = parts[1];
    if ([target hasPrefix:@"http://"] || [target hasPrefix:@"https://"]) {
        NSRange scheme = [target rangeOfString:@"://"];
        NSString *rest = [target substringFromIndex:scheme.location + 3];
        NSRange slash = [rest rangeOfString:@"/"];
        target = (slash.location == NSNotFound) ? @"/" : [rest substringFromIndex:slash.location];
    }

    NSString *rawQuery = nil;
    NSRange question = [target rangeOfString:@"?"];
    if (question.location != NSNotFound) {
        rawQuery = [target substringFromIndex:question.location + 1];
        target = [target substringToIndex:question.location];
    }

    request.path = ISURLDecode(target);
    request.params = ISParseQuery(rawQuery);

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    for (NSUInteger i = 1; i < lines.count; i++) {
        NSString *line = lines[i];
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound) { continue; }
        NSString *name = [[line substringToIndex:colon.location] lowercaseString];
        NSString *value = [[line substringFromIndex:colon.location + 1]
                           stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceCharacterSet]];
        if (name.length) { headers[name] = value; }
    }
    request.headers = headers;

    request.contentLength = [headers[@"content-length"] longLongValue] > 0
        ? (unsigned long long)[headers[@"content-length"] longLongValue] : 0;
    NSString *encoding = [headers[@"transfer-encoding"] lowercaseString];
    // Igual que con expect: si no hay cabecera, rangeOfString sobre nil daba
    // {0,0} y todo cuerpo acababa tratado como chunked (y colgado).
    request.chunked = encoding &&
        [encoding rangeOfString:@"chunked"].location != NSNotFound;

    return request;
}

#pragma mark - Enrutado

- (void)dispatchRequest:(ISHTTPRequest *)request fd:(int)fd buffer:(NSMutableData *)buffer {
    NSString *path = request.path;
    BOOL head = [request.method isEqualToString:@"HEAD"];
    BOOL get = [request.method isEqualToString:@"GET"] || head;
    BOOL post = [request.method isEqualToString:@"POST"] ||
                [request.method isEqualToString:@"PUT"];

    if ([request.method isEqualToString:@"OPTIONS"]) {
        [self sendData:[NSData data] status:204 contentType:@"text/plain"
                            extraHeaders:@{ @"Allow": @"GET, HEAD, POST, PUT, OPTIONS" }
                                 fd:fd head:NO];
        return;
    }

    if (get) {
        if ([path isEqualToString:@"/"] || [path isEqualToString:@"/index.html"]) {
            [self serveWebResource:@"index" type:@"html"
                              mime:@"text/html; charset=utf-8" fd:fd head:head];
            return;
        }
        if ([path isEqualToString:@"/style.css"]) {
            [self serveWebResource:@"style" type:@"css"
                              mime:@"text/css; charset=utf-8" fd:fd head:head];
            return;
        }
        if ([path isEqualToString:@"/app.js"]) {
            [self serveWebResource:@"app" type:@"js"
                              mime:@"application/javascript; charset=utf-8" fd:fd head:head];
            return;
        }
        if ([path isEqualToString:@"/favicon.ico"]) {
            [self sendData:[NSData data] status:204 contentType:@"image/x-icon"
                                extraHeaders:nil fd:fd head:YES];
            return;
        }
        if ([path isEqualToString:@"/api/ping"]) {
            [self sendJSON:@{ @"ok": @YES, @"app": @"ISend" } status:200 fd:fd head:head];
            return;
        }
        if ([path isEqualToString:@"/api/info"]) {
            [self handleInfo:request fd:fd head:head];
            return;
        }
        if ([path isEqualToString:@"/api/list"]) {
            [self handleList:request fd:fd head:head];
            return;
        }
        if ([path isEqualToString:@"/api/raw"] || [path isEqualToString:@"/api/download"]) {
            [self handleFile:request fd:fd head:head
                    download:[path isEqualToString:@"/api/download"]];
            return;
        }
        [self sendJSON:@{ @"ok": @NO, @"error": @"No encontrado" }
                status:404 fd:fd head:head];
        return;
    }

    if (post) {
        if ([path isEqualToString:@"/api/upload"]) {
            [self handleUpload:request fd:fd buffer:buffer];
            return;
        }
        if ([path isEqualToString:@"/api/mkdir"]) {
            [self handleMkdir:request fd:fd];
            return;
        }
        if ([path isEqualToString:@"/api/delete"]) {
            [self handleDelete:request fd:fd];
            return;
        }
        if ([path isEqualToString:@"/api/rename"]) {
            [self handleRename:request fd:fd];
            return;
        }
        [self sendJSON:@{ @"ok": @NO, @"error": @"No encontrado" }
                status:404 fd:fd head:NO];
        return;
    }

    [self sendJSON:@{ @"ok": @NO, @"error": @"Método no permitido" }
            status:405 fd:fd head:NO];
}

#pragma mark - Respuestas

- (void)sendData:(NSData *)data
          status:(int)status
     contentType:(NSString *)contentType
    extraHeaders:(NSDictionary *)extraHeaders
              fd:(int)fd
            head:(BOOL)head {
    NSMutableString *header = [NSMutableString string];
    [header appendFormat:@"HTTP/1.1 %d %@\r\n", status, ISStatusText(status)];
    [header appendFormat:@"Server: ISend/%@\r\n", ISAppVersion()];
    [header appendFormat:@"Date: %@\r\n", ISHTTPDate()];
    [header appendFormat:@"Content-Type: %@\r\n", contentType ?: @"text/plain; charset=utf-8"];
    [header appendFormat:@"Content-Length: %lu\r\n", (unsigned long)data.length];
    [header appendString:@"Connection: close\r\n"];
    [header appendString:@"X-Content-Type-Options: nosniff\r\n"];
    [header appendString:@"Referrer-Policy: no-referrer\r\n"];

    [extraHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        [header appendFormat:@"%@: %@\r\n", key, value];
    }];
    [header appendString:@"\r\n"];

    NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
    if (!ISWriteAll(fd, headerData.bytes, headerData.length)) { return; }
    if (!head && data.length > 0) {
        ISWriteAll(fd, data.bytes, data.length);
        self.bytesOut = self.bytesOut + data.length;
    }
}

- (void)sendText:(NSString *)text status:(int)status fd:(int)fd head:(BOOL)head {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data status:status contentType:@"text/plain; charset=utf-8"
      extraHeaders:@{ @"Cache-Control": @"no-store" } fd:fd head:head];
}

- (void)sendJSON:(id)object status:(int)status fd:(int)fd head:(BOOL)head {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    if (!data) {
        [self sendText:@"No se pudo generar la respuesta JSON." status:500 fd:fd head:head];
        return;
    }
    [self sendData:data status:status contentType:@"application/json; charset=utf-8"
      extraHeaders:@{ @"Cache-Control": @"no-store" } fd:fd head:head];
}

- (void)sendError:(NSString *)message status:(int)status fd:(int)fd {
    [self sendJSON:@{ @"ok": @NO, @"error": message ?: @"Error" }
            status:status fd:fd head:NO];
}

- (void)serveWebResource:(NSString *)name
                    type:(NSString *)type
                    mime:(NSString *)mime
                      fd:(int)fd
                    head:(BOOL)head {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:type
                                                inDirectory:@"web"];
    if (!path) { path = [[NSBundle mainBundle] pathForResource:name ofType:type]; }

    NSData *data = path ? [NSData dataWithContentsOfFile:path] : nil;
    if (!data) {
        [self sendText:@"Falta la interfaz web dentro del IPA (Resources/web)."
                status:500 fd:fd head:head];
        return;
    }
    [self sendData:data status:200 contentType:mime
      extraHeaders:@{ @"Cache-Control": @"no-cache" } fd:fd head:head];
}

#pragma mark - API: informacion y listado

- (void)handleInfo:(ISHTTPRequest *)request fd:(int)fd head:(BOOL)head {
    NSString *root = self.rootPath ?: @"/";
    NSDictionary *info = @{
        @"ok": @YES,
        @"app": @"ISend",
        @"version": ISAppVersion(),
        @"build": ISBuildStamp(),
        @"device": ISDeviceName(),
        @"host": ISLocalHostName(),
        @"root": root,
        @"url": [NSString stringWithFormat:@"http://%@:%d",
                 ISLanIPv4Address(), (int)self.port],
        @"free": @(ISFreeBytesAtPath(root)),
        @"total": @(ISTotalBytesAtPath(root)),
        @"bytesIn": @(self.bytesIn),
        @"bytesOut": @(self.bytesOut),
        @"uploads": @(self.uploadCount),
        @"allowDelete": @(self.allowDelete),
        @"allowUpload": @(self.allowUpload)
    };
    [self sendJSON:info status:200 fd:fd head:head];
}

- (void)handleList:(ISHTTPRequest *)request fd:(int)fd head:(BOOL)head {
    NSString *relative = request.params[@"path"] ?: @"/";
    NSString *directory = ISResolvePath(relative, self.rootPath);
    if (!directory) {
        [self sendError:@"Ruta no permitida" status:403 fd:fd];
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) {
        [self sendError:@"La carpeta no existe" status:404 fd:fd];
        return;
    }

    BOOL showHidden = [request.params[@"hidden"] boolValue];
    NSError *error = nil;
    NSArray *names = [fm contentsOfDirectoryAtPath:directory error:&error];
    if (!names) {
        [self sendError:error.localizedDescription ?: @"No se pudo leer la carpeta"
                status:500 fd:fd];
        return;
    }

    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:names.count];
    for (NSString *name in names) {
        if (!showHidden && [name hasPrefix:@"."]) { continue; }
        NSString *full = [directory stringByAppendingPathComponent:name];

        BOOL itemIsDirectory = NO;
        if (![fm fileExistsAtPath:full isDirectory:&itemIsDirectory]) { continue; }

        NSDictionary *attributes = [fm attributesOfItemAtPath:full error:NULL];
        unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];
        NSDate *date = attributes[NSFileModificationDate];
        NSTimeInterval modified = date ? [date timeIntervalSince1970] : 0;

        NSString *itemRelative = ISRelativePath(full, self.rootPath);
        if (!itemRelative) { continue; }

        [entries addObject:@{
            @"name": name,
            @"path": itemRelative,
            @"dir": @(itemIsDirectory),
            @"size": @(size),
            @"mtime": @(modified),
            @"kind": ISFileKindForPath(full, itemIsDirectory)
        }];
    }

    [entries sortUsingComparator:^NSComparisonResult(id a, id b) {
        NSDictionary *left = (NSDictionary *)a;
        NSDictionary *right = (NSDictionary *)b;
        BOOL aDir = [left[@"dir"] boolValue];
        BOOL bDir = [right[@"dir"] boolValue];
        if (aDir != bDir) { return aDir ? NSOrderedAscending : NSOrderedDescending; }
        return [left[@"name"] localizedCaseInsensitiveCompare:right[@"name"]];
    }];

    NSString *parent = @"/";
    if (![relative isEqualToString:@"/"]) {
        parent = [relative stringByDeletingLastPathComponent];
        if (!parent.length) { parent = @"/"; }
    }

    [self sendJSON:@{
        @"ok": @YES,
        @"path": relative,
        @"parent": parent,
        @"root": self.rootPath ?: @"/",
        @"free": @(ISFreeBytesAtPath(directory)),
        @"entries": entries
    } status:200 fd:fd head:head];
}

#pragma mark - API: descarga

- (void)handleFile:(ISHTTPRequest *)request fd:(int)fd head:(BOOL)head download:(BOOL)download {
    NSString *relative = request.params[@"path"];
    NSString *full = ISResolvePath(relative, self.rootPath);
    if (!full) {
        [self sendError:@"Ruta no permitida" status:403 fd:fd];
        return;
    }

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDirectory] ||
        isDirectory) {
        [self sendError:@"El archivo no existe" status:404 fd:fd];
        return;
    }

    [self sendFileAtPath:full download:download request:request fd:fd head:head];
}

- (void)sendFileAtPath:(NSString *)filePath
              download:(BOOL)download
               request:(ISHTTPRequest *)request
                    fd:(int)fd
                  head:(BOOL)head {
    NSDictionary *attributes = [[NSFileManager defaultManager]
                                attributesOfItemAtPath:filePath error:NULL];
    unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];

    int file = open([filePath fileSystemRepresentation], O_RDONLY);
    if (file < 0) {
        [self sendError:@"No se pudo abrir el archivo" status:500 fd:fd];
        return;
    }

    unsigned long long start = 0;
    unsigned long long end = (size > 0) ? size - 1 : 0;
    BOOL partial = NO;
    NSString *range = request.headers[@"range"];

    if ([range hasPrefix:@"bytes="]) {
        NSString *spec = [range substringFromIndex:6];
        NSArray *parts = [spec componentsSeparatedByString:@"-"];
        if (parts.count == 2) {
            NSString *first = parts[0];
            NSString *second = parts[1];
            if (!first.length && second.length) {
                unsigned long long suffix = [second longLongValue];
                if (suffix > 0 && suffix <= size) {
                    start = size - suffix;
                    partial = YES;
                }
            } else if (first.length) {
                start = [first longLongValue];
                if (second.length) { end = [second longLongValue]; }
                if (end >= size) { end = (size > 0) ? size - 1 : 0; }
                if (start <= end && start < size) { partial = YES; }
            }
        }
    }

    if ((size > 0 && start >= size) || (partial && start > end)) {
        close(file);
        NSString *header = [NSString stringWithFormat:
            @"HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */%llu\r\n"
            @"Content-Length: 0\r\nConnection: close\r\n\r\n", size];
        NSData *data = [header dataUsingEncoding:NSUTF8StringEncoding];
        ISWriteAll(fd, data.bytes, data.length);
        return;
    }

    unsigned long long length = (size == 0) ? 0 : (end - start + 1);
    NSString *mime = ISMIMETypeForPath(filePath);

    // Un HTML o un SVG subido por el usuario no debe ejecutar scripts en el
    // mismo origen que la interfaz (podria borrar archivos).
    NSString *extension = [[filePath pathExtension] lowercaseString];
    if (!download && ([extension isEqualToString:@"html"] ||
                      [extension isEqualToString:@"htm"] ||
                      [extension isEqualToString:@"svg"] ||
                      [extension isEqualToString:@"xhtml"])) {
        mime = @"text/plain; charset=utf-8";
    }

    NSString *rawName = [filePath lastPathComponent];
    NSString *asciiName = [rawName stringByReplacingOccurrencesOfString:@"\""
                                                             withString:@"'"];

    NSMutableString *header = [NSMutableString string];
    [header appendFormat:@"HTTP/1.1 %d %@\r\n", partial ? 206 : 200,
                         ISStatusText(partial ? 206 : 200)];
    [header appendFormat:@"Server: ISend/%@\r\n", ISAppVersion()];
    [header appendFormat:@"Date: %@\r\n", ISHTTPDate()];
    [header appendFormat:@"Content-Type: %@\r\n", mime];
    [header appendFormat:@"Content-Length: %llu\r\n", length];
    [header appendString:@"Accept-Ranges: bytes\r\n"];
    [header appendString:@"Connection: close\r\n"];
    [header appendString:@"X-Content-Type-Options: nosniff\r\n"];
    [header appendFormat:@"Content-Disposition: %@; filename=\"%@\"; filename*=UTF-8''%@\r\n",
                         download ? @"attachment" : @"inline", asciiName,
                         ISPercentEncode(rawName)];
    [header appendString:@"Cache-Control: no-cache\r\n"];
    if (partial) {
        [header appendFormat:@"Content-Range: bytes %llu-%llu/%llu\r\n", start, end, size];
    }
    [header appendString:@"\r\n"];

    NSData *headerData = [header dataUsingEncoding:NSUTF8StringEncoding];
    if (!ISWriteAll(fd, headerData.bytes, headerData.length)) {
        close(file);
        return;
    }

    if (!head && length > 0) {
        NSUInteger chunkSize = 128 * 1024;
        uint8_t *chunk = malloc(chunkSize);
        if (chunk) {
            unsigned long long remaining = length;
            off_t offset = (off_t)start;
            while (remaining > 0) {
                NSUInteger want = (NSUInteger)MIN((unsigned long long)chunkSize, remaining);
                ssize_t got = pread(file, chunk, want, offset);
                if (got <= 0) { break; }
                if (!ISWriteAll(fd, chunk, (NSUInteger)got)) { break; }
                offset += got;
                remaining -= (unsigned long long)got;
                self.bytesOut = self.bytesOut + (unsigned long long)got;
            }
            free(chunk);
        }
    }

    close(file);
}

#pragma mark - API: escritura

- (BOOL)consumeFixedBody:(unsigned long long)length
                      fd:(int)fd
                  buffer:(NSMutableData *)buffer
                   outFD:(int)out
                 written:(unsigned long long *)written
               errorCode:(int *)errorCode {
    unsigned long long remaining = length;
    while (remaining > 0) {
        if (buffer.length == 0) {
            if (!ISReceiveMore(fd, buffer)) {
                if (errorCode) { *errorCode = errno ? errno : -1; }
                return NO;
            }
            continue;
        }
        NSUInteger take = (NSUInteger)MIN((unsigned long long)buffer.length, remaining);
        if (!ISWriteFileAll(out, buffer.bytes, take)) {
            if (errorCode) { *errorCode = errno ? errno : -1; }
            return NO;
        }
        [buffer replaceBytesInRange:NSMakeRange(0, take) withBytes:NULL length:0];
        remaining -= take;
        *written += take;
    }
    return YES;
}

- (NSString *)readLineFrom:(int)fd buffer:(NSMutableData *)buffer {
    static NSData *crlf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        crlf = [@"\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    });

    NSRange found = [buffer rangeOfData:crlf options:0 range:NSMakeRange(0, buffer.length)];
    while (found.location == NSNotFound) {
        if (buffer.length > 16384) { return nil; }
        if (!ISReceiveMore(fd, buffer)) { return nil; }
        found = [buffer rangeOfData:crlf options:0 range:NSMakeRange(0, buffer.length)];
    }

    NSData *lineData = [buffer subdataWithRange:NSMakeRange(0, found.location)];
    [buffer replaceBytesInRange:NSMakeRange(0, found.location + crlf.length)
                      withBytes:NULL length:0];
    NSString *line = [[NSString alloc] initWithData:lineData encoding:NSASCIIStringEncoding];
    return line ?: @"";
}

- (BOOL)consumeChunkedBody:(int)fd
                    buffer:(NSMutableData *)buffer
                     outFD:(int)out
                   written:(unsigned long long *)written
                 errorCode:(int *)errorCode {
    while (YES) {
        NSString *line = [self readLineFrom:fd buffer:buffer];
        if (!line) {
            if (errorCode) { *errorCode = errno ? errno : -1; }
            return NO;
        }

        unsigned long long chunkLength = 0;
        if (sscanf([line UTF8String], "%llx", &chunkLength) != 1) {
            if (errorCode) { *errorCode = -2; }  // cabecera de bloque invalida
            return NO;
        }

        if (chunkLength == 0) {
            NSString *trailer = nil;
            do {
                trailer = [self readLineFrom:fd buffer:buffer];
            } while (trailer && trailer.length > 0);
            return YES;
        }

        unsigned long long remaining = chunkLength;
        while (remaining > 0) {
            if (buffer.length == 0 && !ISReceiveMore(fd, buffer)) {
                if (errorCode) { *errorCode = errno ? errno : -1; }
                return NO;
            }
            NSUInteger take = (NSUInteger)MIN((unsigned long long)buffer.length, remaining);
            if (!ISWriteFileAll(out, buffer.bytes, take)) {
                if (errorCode) { *errorCode = errno ? errno : -1; }
                return NO;
            }
            [buffer replaceBytesInRange:NSMakeRange(0, take) withBytes:NULL length:0];
            remaining -= take;
            *written += take;
        }

        NSString *crlf = [self readLineFrom:fd buffer:buffer];
        if (!crlf) {
            if (errorCode) { *errorCode = errno ? errno : -1; }
            return NO;
        }
    }
}

- (void)handleUpload:(ISHTTPRequest *)request fd:(int)fd buffer:(NSMutableData *)buffer {
    if (!self.allowUpload) {
        [self sendError:@"La subida de archivos está desactivada en el iPad."
                status:403 fd:fd];
        return;
    }

    NSString *relative = request.params[@"path"] ?: @"/";
    NSString *directory = ISResolvePath(relative, self.rootPath);
    if (!directory) {
        [self sendError:@"Ruta no permitida" status:403 fd:fd];
        return;
    }

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:directory isDirectory:&isDirectory] ||
        !isDirectory) {
        [self sendError:@"La carpeta de destino no existe" status:404 fd:fd];
        return;
    }

    NSString *name = request.params[@"name"] ?: request.headers[@"x-file-name"];
    name = ISSafeFileName(name);
    if (!name.length) {
        [self sendError:@"Falta el nombre del archivo" status:400 fd:fd];
        return;
    }

    NSString *finalPath = ISUniquePath(directory, name);
    NSString *temporary = [directory stringByAppendingPathComponent:
                           [NSString stringWithFormat:@".isend-%@.part",
                            [[NSUUID UUID] UUIDString]]];

    int out = open([temporary fileSystemRepresentation], O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out < 0) {
        [self sendError:@"No se pudo crear el archivo en el iPad" status:500 fd:fd];
        return;
    }

    unsigned long long written = 0;
    int ioError = 0;
    BOOL ok;
    if (request.chunked) {
        ok = [self consumeChunkedBody:fd buffer:buffer outFD:out written:&written
                            errorCode:&ioError];
    } else {
        ok = [self consumeFixedBody:request.contentLength fd:fd buffer:buffer
                              outFD:out written:&written errorCode:&ioError];
    }
    close(out);

    if (!ok) {
        [[NSFileManager defaultManager] removeItemAtPath:temporary error:NULL];
        [self sendJSON:@{ @"ok": @NO,
                          @"error": @"La transferencia se interrumpió",
                          @"code": @(ioError) }
                status:400 fd:fd head:NO];
        return;
    }

    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtPath:temporary
                                                 toPath:finalPath error:&error]) {
        [[NSFileManager defaultManager] removeItemAtPath:temporary error:NULL];
        [self sendError:error.localizedDescription ?: @"No se pudo guardar el archivo"
                status:500 fd:fd];
        return;
    }

    self.bytesIn = self.bytesIn + written;
    self.uploadCount = self.uploadCount + 1;
    [self notifyFilesChanged];

    NSString *relativeFinal = ISRelativePath(finalPath, self.rootPath) ?: @"/";
    [self sendJSON:@{
        @"ok": @YES,
        @"name": [finalPath lastPathComponent],
        @"path": relativeFinal,
        @"size": @(written)
    } status:200 fd:fd head:NO];
}

- (void)handleMkdir:(ISHTTPRequest *)request fd:(int)fd {
    NSString *directory = ISResolvePath(request.params[@"path"] ?: @"/", self.rootPath);
    if (!directory) {
        [self sendError:@"Ruta no permitida" status:403 fd:fd];
        return;
    }

    NSString *name = ISSafeFileName(request.params[@"name"]);
    if (!name.length) {
        [self sendError:@"Falta el nombre de la carpeta" status:400 fd:fd];
        return;
    }

    NSString *target = [directory stringByAppendingPathComponent:name];
    NSError *error = nil;
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:target isDirectory:&isDirectory]) {
        if (isDirectory) {
            [self sendJSON:@{ @"ok": @YES, @"path": ISRelativePath(target, self.rootPath) }
                    status:200 fd:fd head:NO];
        } else {
            [self sendError:@"Ya existe un archivo con ese nombre" status:409 fd:fd];
        }
        return;
    }

    if (![[NSFileManager defaultManager] createDirectoryAtPath:target
                                   withIntermediateDirectories:NO
                                                    attributes:nil error:&error]) {
        // Si dos subidas crean la misma carpeta a la vez, la segunda recibe
        // "ya existe": lo tratamos como exito.
        BOOL nowDirectory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:target
                                               isDirectory:&nowDirectory] && nowDirectory) {
            [self sendJSON:@{ @"ok": @YES, @"path": ISRelativePath(target, self.rootPath) }
                    status:200 fd:fd head:NO];
            return;
        }
        [self sendError:error.localizedDescription ?: @"No se pudo crear la carpeta"
                status:500 fd:fd];
        return;
    }

    [self notifyFilesChanged];
    [self sendJSON:@{ @"ok": @YES, @"path": ISRelativePath(target, self.rootPath) }
            status:200 fd:fd head:NO];
}

- (void)handleDelete:(ISHTTPRequest *)request fd:(int)fd {
    if (!self.allowDelete) {
        [self sendError:@"Borrar está desactivado en el iPad" status:403 fd:fd];
        return;
    }

    NSString *relative = request.params[@"path"];
    NSString *full = ISResolvePath(relative, self.rootPath);
    NSString *root = [self.rootPath stringByStandardizingPath];

    if (!full || [full isEqualToString:root]) {
        [self sendError:@"No se puede borrar la carpeta compartida" status:403 fd:fd];
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:full]) {
        [self sendError:@"El archivo no existe" status:404 fd:fd];
        return;
    }

    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:full error:&error]) {
        [self sendError:error.localizedDescription ?: @"No se pudo borrar" status:500 fd:fd];
        return;
    }

    [self notifyFilesChanged];
    [self sendJSON:@{ @"ok": @YES } status:200 fd:fd head:NO];
}

- (void)handleRename:(ISHTTPRequest *)request fd:(int)fd {
    NSString *full = ISResolvePath(request.params[@"path"], self.rootPath);
    NSString *root = [self.rootPath stringByStandardizingPath];
    if (!full || [full isEqualToString:root]) {
        [self sendError:@"No se puede renombrar la carpeta compartida" status:403 fd:fd];
        return;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:full]) {
        [self sendError:@"El archivo no existe" status:404 fd:fd];
        return;
    }

    NSString *name = ISSafeFileName(request.params[@"name"]);
    if (!name.length) {
        [self sendError:@"Falta el nombre nuevo" status:400 fd:fd];
        return;
    }

    NSString *directory = [full stringByDeletingLastPathComponent];
    NSString *target = [directory stringByAppendingPathComponent:name];
    if ([target isEqualToString:full]) {
        [self sendJSON:@{ @"ok": @YES, @"path": ISRelativePath(full, self.rootPath) }
                status:200 fd:fd head:NO];
        return;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:target]) {
        [self sendError:@"Ya existe un elemento con ese nombre" status:409 fd:fd];
        return;
    }

    NSError *error = nil;
    if (![[NSFileManager defaultManager] moveItemAtPath:full toPath:target error:&error]) {
        [self sendError:error.localizedDescription ?: @"No se pudo renombrar"
                status:500 fd:fd];
        return;
    }

    [self notifyFilesChanged];
    [self sendJSON:@{ @"ok": @YES, @"path": ISRelativePath(target, self.rootPath) }
            status:200 fd:fd head:NO];
}

#pragma mark - Avisos

- (void)notifyActivity {
    id<ISHTTPServerDelegate> delegate = self.delegate;
    if (delegate && [delegate respondsToSelector:@selector(httpServerDidChangeActivity:)]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) { [delegate httpServerDidChangeActivity:strongSelf]; }
        });
    }
}

- (void)notifyFilesChanged {
    id<ISHTTPServerDelegate> delegate = self.delegate;
    if (delegate && [delegate respondsToSelector:@selector(httpServerDidChangeFiles:)]) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) { [delegate httpServerDidChangeFiles:strongSelf]; }
        });
    }
}

@end
