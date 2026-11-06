#import <Foundation/Foundation.h>

@class ISHTTPServer;

extern NSString * const ISServiceStateDidChangeNotification;
extern NSString * const ISServiceFilesDidChangeNotification;

// Estado global: puerto, carpeta publicada y servidor. Las vistas solo
// hablan con este objeto; nunca con el servidor directamente.
@interface ISService : NSObject

@property (nonatomic, strong, readonly) ISHTTPServer *server;

@property (nonatomic, assign, readonly) uint16_t port;
@property (nonatomic, copy, readonly) NSString *rootPath;
@property (nonatomic, copy, readonly) NSString *rootLabel;

// Se recuerda entre arranques: si estaba encendido, arranca al abrir la app.
@property (nonatomic, assign) BOOL serverEnabled;

// Ajustes compartidos con el servidor (se guardan en NSUserDefaults).
@property (nonatomic, assign) BOOL allowDelete;
@property (nonatomic, assign) BOOL allowUpload;

@property (nonatomic, assign, readonly) BOOL running;
@property (nonatomic, copy, readonly) NSString *currentURL;

@property (nonatomic, assign, readonly) unsigned long long bytesIn;
@property (nonatomic, assign, readonly) unsigned long long bytesOut;
@property (nonatomic, assign, readonly) NSUInteger uploadCount;

+ (instancetype)shared;

- (BOOL)startWithError:(NSString **)error;
- (BOOL)enableAndStart:(NSString **)error;
- (void)stop;
- (void)disable;
- (void)restart;

// Al pasar a segundo plano iOS suspende la app y cierra los sockets.
- (void)suspendForBackground;
- (void)resumeAfterForeground;

- (BOOL)applyRootPath:(NSString *)path error:(NSString **)error;
- (BOOL)applyPort:(uint16_t)port error:(NSString **)error;

- (NSString *)resolveRelativePath:(NSString *)relative;
- (void)notifyFilesChanged;

@end
