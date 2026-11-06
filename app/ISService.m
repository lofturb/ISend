#import "ISService.h"
#import "ISHTTPServer.h"
#import "ISPaths.h"

NSString * const ISServiceStateDidChangeNotification = @"ISServiceStateDidChangeNotification";
NSString * const ISServiceFilesDidChangeNotification = @"ISServiceFilesDidChangeNotification";

static NSString * const ISPortKey = @"isend.port";
static NSString * const ISEnabledKey = @"isend.enabled";
static NSString * const ISRootKey = @"isend.root";
static NSString * const ISAllowDeleteKey = @"isend.allowDelete";
static NSString * const ISAllowUploadKey = @"isend.allowUpload";

@interface ISService () <ISHTTPServerDelegate>
@property (nonatomic, strong, readwrite) ISHTTPServer *server;
@property (nonatomic, assign, readwrite) uint16_t port;
@property (nonatomic, copy, readwrite) NSString *rootPath;
@end

@implementation ISService

+ (instancetype)shared {
    static ISService *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[ISService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        ISPortKey: @8080,
        ISEnabledKey: @YES,
        ISAllowDeleteKey: @YES,
        ISAllowUploadKey: @YES
    }];

    NSInteger storedPort = [defaults integerForKey:ISPortKey];
    if (storedPort < 1024 || storedPort > 65535) { storedPort = 8080; }
    _port = (uint16_t)storedPort;
    _serverEnabled = [defaults boolForKey:ISEnabledKey];

    NSString *storedRoot = [defaults stringForKey:ISRootKey];
    if (!storedRoot.length) {
        storedRoot = ISAppDocumentsDirectory();
    }
    _rootPath = [storedRoot copy];

    _server = [[ISHTTPServer alloc] init];
    _server.delegate = self;
    _server.rootPath = _rootPath;
    _server.allowDelete = [defaults boolForKey:ISAllowDeleteKey];
    _server.allowUpload = [defaults boolForKey:ISAllowUploadKey];

    return self;
}

#pragma mark - Estado

- (void)setServerEnabled:(BOOL)enabled {
    _serverEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:ISEnabledKey];
}

- (BOOL)running {
    return self.server.running;
}

- (NSString *)currentURL {
    if (!self.server.running) { return nil; }
    return [NSString stringWithFormat:@"http://%@:%d",
            ISLanIPv4Address(), (int)self.server.port];
}

- (NSString *)rootLabel {
    NSString *documents = [ISAppDocumentsDirectory() stringByStandardizingPath];
    NSString *root = [self.rootPath stringByStandardizingPath];
    if ([root isEqualToString:documents]) { return @"Documentos de ISend"; }
    if ([root isEqualToString:@"/var/mobile/Documents"]) { return @"/var/mobile/Documents"; }
    if ([root isEqualToString:@"/"]) { return @"Raíz del sistema"; }
    return [root lastPathComponent] ?: root;
}

- (unsigned long long)bytesIn { return self.server.bytesIn; }
- (unsigned long long)bytesOut { return self.server.bytesOut; }
- (NSUInteger)uploadCount { return self.server.uploadCount; }

#pragma mark - Arranque y parada

- (BOOL)startWithError:(NSString **)error {
    NSError *directoryError = nil;
    if (!ISEnsureDirectory(self.rootPath, &directoryError)) {
        if (error) {
            *error = [NSString stringWithFormat:@"No se puede usar la carpeta %@: %@",
                      self.rootPath, directoryError.localizedDescription ?: @"error desconocido"];
        }
        return NO;
    }

    self.server.rootPath = self.rootPath;
    self.server.allowDelete = [[NSUserDefaults standardUserDefaults] boolForKey:ISAllowDeleteKey];
    self.server.allowUpload = [[NSUserDefaults standardUserDefaults] boolForKey:ISAllowUploadKey];

    BOOL started = [self.server startOnPort:self.port error:error];
    if (started) { [self postState]; }
    return started;
}

- (BOOL)enableAndStart:(NSString **)error {
    NSString *reason = nil;
    if (![self startWithError:&reason]) {
        self.serverEnabled = NO;
        if (error) { *error = reason; }
        return NO;
    }
    self.serverEnabled = YES;
    return YES;
}

- (void)stop {
    [self.server stop];
    [self postState];
}

- (void)disable {
    self.serverEnabled = NO;
    [self stop];
}

- (void)restart {
    BOOL wasRunning = self.server.running;
    [self.server stop];
    if (wasRunning) {
        [self startWithError:NULL];
    }
    [self postState];
}

- (void)suspendForBackground {
    if (self.server.running) { [self.server stop]; }
    [self postState];
}

- (void)resumeAfterForeground {
    if (self.serverEnabled && !self.server.running) {
        if (![self startWithError:NULL]) {
            self.serverEnabled = NO;
            [self postState];
        }
    }
}

#pragma mark - Ajustes

- (BOOL)applyRootPath:(NSString *)path error:(NSString **)error {
    if (!path.length) {
        if (error) { *error = @"La ruta está vacía."; }
        return NO;
    }

    NSString *standardized = [path stringByStandardizingPath];
    NSError *directoryError = nil;
    if (!ISEnsureDirectory(standardized, &directoryError)) {
        if (error) {
            *error = [NSString stringWithFormat:@"No se puede usar esa carpeta: %@",
                      directoryError.localizedDescription ?: @"error desconocido"];
        }
        return NO;
    }

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:standardized
                                             isDirectory:&isDirectory] || !isDirectory) {
        if (error) { *error = @"La ruta no es una carpeta."; }
        return NO;
    }

    NSString *previous = self.rootPath;
    self.rootPath = standardized;
    [[NSUserDefaults standardUserDefaults] setObject:standardized forKey:ISRootKey];

    if (self.server.running) {
        [self.server stop];
        NSString *reason = nil;
        if (![self startWithError:&reason]) {
            self.rootPath = previous;
            [[NSUserDefaults standardUserDefaults] setObject:previous forKey:ISRootKey];
            [self startWithError:NULL];
            if (error) { *error = reason; }
            return NO;
        }
    }

    [self postState];
    return YES;
}

- (BOOL)applyPort:(uint16_t)port error:(NSString **)error {
    if (port < 1024) {
        if (error) { *error = @"Usa un puerto entre 1024 y 65535."; }
        return NO;
    }

    uint16_t previous = self.port;
    self.port = port;
    [[NSUserDefaults standardUserDefaults] setInteger:port forKey:ISPortKey];

    if (self.server.running) {
        [self.server stop];
        NSString *reason = nil;
        if (![self startWithError:&reason]) {
            self.port = previous;
            [[NSUserDefaults standardUserDefaults] setInteger:previous forKey:ISPortKey];
            [self startWithError:NULL];
            if (error) { *error = reason; }
            return NO;
        }
    }

    [self postState];
    return YES;
}

- (NSString *)resolveRelativePath:(NSString *)relative {
    return ISResolvePath(relative, self.rootPath);
}

#pragma mark - Ajustes compartidos con el servidor

- (BOOL)allowDelete {
    return [[NSUserDefaults standardUserDefaults] boolForKey:ISAllowDeleteKey];
}

- (void)setAllowDelete:(BOOL)allow {
    [[NSUserDefaults standardUserDefaults] setBool:allow forKey:ISAllowDeleteKey];
    self.server.allowDelete = allow;
}

- (BOOL)allowUpload {
    return [[NSUserDefaults standardUserDefaults] boolForKey:ISAllowUploadKey];
}

- (void)setAllowUpload:(BOOL)allow {
    [[NSUserDefaults standardUserDefaults] setBool:allow forKey:ISAllowUploadKey];
    self.server.allowUpload = allow;
}

#pragma mark - Avisos

- (void)postState {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:ISServiceStateDidChangeNotification object:self];
}

- (void)notifyFilesChanged {
    [[NSNotificationCenter defaultCenter]
        postNotificationName:ISServiceFilesDidChangeNotification object:self];
}

- (void)httpServerDidChangeActivity:(ISHTTPServer *)server {
    [self postState];
}

- (void)httpServerDidChangeFiles:(ISHTTPServer *)server {
    [self notifyFilesChanged];
}

@end
