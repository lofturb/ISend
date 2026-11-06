#import <Foundation/Foundation.h>

@class ISHTTPServer;

@protocol ISHTTPServerDelegate <NSObject>
@optional
- (void)httpServerDidChangeActivity:(ISHTTPServer *)server;
- (void)httpServerDidChangeFiles:(ISHTTPServer *)server;
@end

// Servidor HTTP minimo para la red local. Una peticion por conexion
// (Connection: close), lo que evita estados raros con navegadores viejos.
@interface ISHTTPServer : NSObject

@property (nonatomic, weak) id<ISHTTPServerDelegate> delegate;

// Carpeta raiz que se publica. Todo lo que pida el navegador se resuelve
// contra esta ruta y no puede salirse de ella.
@property (atomic, copy) NSString *rootPath;
@property (atomic, assign) BOOL allowDelete;
@property (atomic, assign) BOOL allowUpload;

@property (atomic, assign, readonly) BOOL running;
@property (atomic, assign, readonly) uint16_t port;
@property (atomic, assign, readonly) unsigned long long bytesIn;
@property (atomic, assign, readonly) unsigned long long bytesOut;
@property (atomic, assign, readonly) NSUInteger uploadCount;
@property (atomic, assign, readonly) NSUInteger requestCount;

- (BOOL)startOnPort:(uint16_t)port error:(NSString **)error;
- (void)stop;
- (void)resetCounters;

@end
