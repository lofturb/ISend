#import "ISPaths.h"
#import <ifaddrs.h>
#import <net/if.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <string.h>
#import <stdlib.h>

NSString * const ISAppVersion = @"1.0.0";

NSString *ISAppDocumentsDirectory(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *path = paths.count ? paths[0] : NSTemporaryDirectory();
    ISEnsureDirectory(path, NULL);
    return path;
}

NSString *ISDeviceName(void) {
    NSString *name = [[UIDevice currentDevice] name];
    return name.length ? name : @"iPad";
}

NSString *ISLocalHostName(void) {
    NSString *host = [[NSProcessInfo processInfo] hostName];
    return host.length ? host : @"";
}

unsigned long long ISFreeBytesAtPath(NSString *path) {
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager]
                           attributesOfFileSystemForPath:path error:&error];
    if (!attrs) { return 0; }
    return [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
}

unsigned long long ISTotalBytesAtPath(NSString *path) {
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager]
                           attributesOfFileSystemForPath:path error:&error];
    if (!attrs) { return 0; }
    return [attrs[NSFileSystemSize] unsignedLongLongValue];
}

NSString *ISFormatBytes(unsigned long long bytes) {
    NSByteCountFormatter *f = [[NSByteCountFormatter alloc] init];
    f.countStyle = NSByteCountFormatterCountStyleFile;
    f.allowsNonnumericFormatting = NO;
    return [f stringFromByteCount:(long long)bytes];
}

NSString *ISFormatDate(NSDate *date) {
    if (!date) { return @""; }
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"es_ES"];
        formatter.dateFormat = @"d MMM yyyy, HH:mm";
    });
    return [formatter stringFromDate:date];
}

#pragma mark - Tipos de archivo

static NSDictionary *ISMIMEMap(void) {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"html": @"text/html; charset=utf-8",
            @"htm":  @"text/html; charset=utf-8",
            @"css":  @"text/css; charset=utf-8",
            @"js":   @"application/javascript; charset=utf-8",
            @"json": @"application/json; charset=utf-8",
            @"txt":  @"text/plain; charset=utf-8",
            @"md":   @"text/plain; charset=utf-8",
            @"xml":  @"text/xml; charset=utf-8",
            @"plist":@"text/xml; charset=utf-8",
            @"csv":  @"text/csv; charset=utf-8",
            @"log":  @"text/plain; charset=utf-8",
            @"png":  @"image/png",
            @"jpg":  @"image/jpeg",
            @"jpeg": @"image/jpeg",
            @"gif":  @"image/gif",
            @"webp": @"image/webp",
            @"bmp":  @"image/bmp",
            @"tif":  @"image/tiff",
            @"tiff": @"image/tiff",
            @"heic": @"image/heic",
            @"heif": @"image/heif",
            @"svg":  @"image/svg+xml",
            @"ico":  @"image/x-icon",
            @"pdf":  @"application/pdf",
            @"mp4":  @"video/mp4",
            @"m4v":  @"video/mp4",
            @"mov":  @"video/quicktime",
            @"3gp":  @"video/3gpp",
            @"mkv":  @"video/x-matroska",
            @"avi":  @"video/x-msvideo",
            @"webm": @"video/webm",
            @"mp3":  @"audio/mpeg",
            @"m4a":  @"audio/mp4",
            @"aac":  @"audio/aac",
            @"wav":  @"audio/wav",
            @"aiff": @"audio/aiff",
            @"flac": @"audio/flac",
            @"ogg":  @"audio/ogg",
            @"zip":  @"application/zip",
            @"7z":   @"application/x-7z-compressed",
            @"rar":  @"application/x-rar-compressed",
            @"gz":   @"application/gzip",
            @"tar":  @"application/x-tar",
            @"ipa":  @"application/octet-stream",
            @"deb":  @"application/x-debian-package",
            @"dylib":@"application/octet-stream",
            @"epub": @"application/epub+zip",
            @"doc":  @"application/msword",
            @"docx": @"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            @"xls":  @"application/vnd.ms-excel",
            @"xlsx": @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            @"ppt":  @"application/vnd.ms-powerpoint",
            @"pptx": @"application/vnd.openxmlformats-officedocument.presentationml.presentation",
            @"ttf":  @"font/ttf",
            @"otf":  @"font/otf",
            @"woff": @"font/woff",
            @"woff2":@"font/woff2"
        };
    });
    return map;
}

NSString *ISMIMETypeForPath(NSString *path) {
    NSString *ext = [[path pathExtension] lowercaseString];
    if (ext.length == 0) { return @"application/octet-stream"; }
    NSString *mime = ISMIMEMap()[ext];
    return mime ?: @"application/octet-stream";
}

NSString *ISFileKindForPath(NSString *path, BOOL isDirectory) {
    if (isDirectory) { return @"folder"; }
    NSString *ext = [[path pathExtension] lowercaseString];

    NSSet *images = [NSSet setWithObjects:@"png", @"jpg", @"jpeg", @"gif", @"webp",
                     @"bmp", @"tif", @"tiff", @"heic", @"heif", @"svg", @"ico", nil];
    NSSet *videos = [NSSet setWithObjects:@"mp4", @"m4v", @"mov", @"3gp", @"mkv",
                     @"avi", @"webm", nil];
    NSSet *audio = [NSSet setWithObjects:@"mp3", @"m4a", @"aac", @"wav", @"aiff",
                    @"flac", @"ogg", nil];
    NSSet *archives = [NSSet setWithObjects:@"zip", @"7z", @"rar", @"gz", @"tar",
                       @"ipa", @"deb", nil];
    NSSet *text = [NSSet setWithObjects:@"txt", @"md", @"csv", @"log", @"json",
                   @"xml", @"plist", @"html", @"htm", @"css", @"js", @"py", @"sh",
                   @"c", @"h", @"m", @"swift", nil];

    if ([ext isEqualToString:@"pdf"]) { return @"pdf"; }
    if ([images containsObject:ext]) { return @"image"; }
    if ([videos containsObject:ext]) { return @"video"; }
    if ([audio containsObject:ext]) { return @"audio"; }
    if ([archives containsObject:ext]) { return @"archive"; }
    if ([text containsObject:ext]) { return @"text"; }
    return @"other";
}

NSString *ISEmojiForKind(NSString *kind) {
    if ([kind isEqualToString:@"folder"])  { return @"📁"; }
    if ([kind isEqualToString:@"image"])   { return @"🖼️"; }
    if ([kind isEqualToString:@"video"])   { return @"🎬"; }
    if ([kind isEqualToString:@"audio"])   { return @"🎵"; }
    if ([kind isEqualToString:@"pdf"])     { return @"📕"; }
    if ([kind isEqualToString:@"archive"]) { return @"🗜️"; }
    if ([kind isEqualToString:@"text"])    { return @"📄"; }
    return @"📦";
}

#pragma mark - Red

NSString *ISLanIPv4Address(void) {
    NSString *fallback = nil;
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) { return @"127.0.0.1"; }

    for (struct ifaddrs *ifa = interfaces; ifa != NULL; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) { continue; }
        if (!(ifa->ifa_flags & IFF_UP)) { continue; }

        char buffer[INET_ADDRSTRLEN];
        struct sockaddr_in *addr = (struct sockaddr_in *)ifa->ifa_addr;
        if (!inet_ntop(AF_INET, &addr->sin_addr, buffer, sizeof(buffer))) { continue; }

        NSString *ip = [NSString stringWithUTF8String:buffer];
        if ([ip hasPrefix:@"127."]) { continue; }

        // Se compara con NSString y no con strcmp: el .tbd del SDK 9.3 no
        // exporta _strcmp y el enlazador falla con "symbol(s) not found".
        NSString *interfaceName = ifa->ifa_name
            ? [NSString stringWithUTF8String:ifa->ifa_name] : nil;
        if ([interfaceName isEqualToString:@"en0"]) {
            freeifaddrs(interfaces);
            return ip;
        }
        if (!fallback) { fallback = ip; }
    }
    freeifaddrs(interfaces);
    return fallback ?: @"127.0.0.1";
}

#pragma mark - Nombres y rutas

NSString *ISSafeFileName(NSString *name) {
    if (!name.length) { return nil; }
    NSString *clean = [name lastPathComponent];
    clean = [clean stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    clean = [clean stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
    clean = [clean stringByTrimmingCharactersInSet:
             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([clean isEqualToString:@""] || [clean isEqualToString:@"."] ||
        [clean isEqualToString:@".."]) {
        return nil;
    }
    if (clean.length > 200) {
        clean = [clean substringToIndex:200];
    }
    return clean;
}

NSString *ISUniquePath(NSString *directory, NSString *fileName) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *candidate = [directory stringByAppendingPathComponent:fileName];
    if (![fm fileExistsAtPath:candidate]) { return candidate; }

    NSString *base = [fileName stringByDeletingPathExtension];
    NSString *ext = [fileName pathExtension];
    NSInteger n = 2;
    while (n < 1000) {
        NSString *name = ext.length
            ? [NSString stringWithFormat:@"%@ (%ld).%@", base, (long)n, ext]
            : [NSString stringWithFormat:@"%@ (%ld)", base, (long)n];
        candidate = [directory stringByAppendingPathComponent:name];
        if (![fm fileExistsAtPath:candidate]) { return candidate; }
        n++;
    }
    return [directory stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@-%u.%@", base, arc4random(), ext]];
}

BOOL ISEnsureDirectory(NSString *path, NSError **error) {
    BOOL isDir = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
        return isDir;
    }
    return [fm createDirectoryAtPath:path withIntermediateDirectories:YES
                          attributes:nil error:error];
}

NSString *ISRelativePath(NSString *fullPath, NSString *rootPath) {
    if (!fullPath.length || !rootPath.length) { return nil; }
    NSString *root = [rootPath stringByStandardizingPath];
    NSString *full = [fullPath stringByStandardizingPath];

    if ([root isEqualToString:@"/"]) {
        return [full hasPrefix:@"/"] ? full : nil;
    }
    if ([full isEqualToString:root]) { return @"/"; }
    NSString *prefix = [root stringByAppendingString:@"/"];
    if ([full hasPrefix:prefix]) {
        return [@"/" stringByAppendingString:[full substringFromIndex:prefix.length]];
    }
    return nil;
}

NSString *ISResolvePath(NSString *relativePath, NSString *rootPath) {
    if (!rootPath.length) { return nil; }
    NSString *root = [rootPath stringByStandardizingPath];
    NSString *rel = relativePath.length ? relativePath : @"/";
    if (![rel hasPrefix:@"/"]) {
        rel = [@"/" stringByAppendingString:rel];
    }

    NSString *full;
    if ([root isEqualToString:@"/"]) {
        full = [rel stringByStandardizingPath];
    } else {
        full = [[root stringByAppendingPathComponent:rel] stringByStandardizingPath];
    }

    if ([root isEqualToString:@"/"]) {
        return [full hasPrefix:@"/"] ? full : nil;
    }
    if ([full isEqualToString:root]) { return full; }
    if ([full hasPrefix:[root stringByAppendingString:@"/"]]) { return full; }
    return nil;
}
