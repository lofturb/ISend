#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Version real de la app, leida de Info.plist (CFBundleShortVersionString).
NSString *ISAppVersion(void);

// Rutas y utilidades compartidas por la app y el servidor.

NSString *ISAppDocumentsDirectory(void);
NSString *ISDeviceName(void);
NSString *ISLocalHostName(void);

unsigned long long ISFreeBytesAtPath(NSString *path);
unsigned long long ISTotalBytesAtPath(NSString *path);

// "1,4 MB" con separador espanol.
NSString *ISFormatBytes(unsigned long long bytes);
NSString *ISFormatDate(NSDate *date);

// Tipo MIME a partir de la extension del archivo.
NSString *ISMIMETypeForPath(NSString *path);

// Categoria logica: folder, image, video, audio, pdf, archive, text, code, other.
NSString *ISFileKindForPath(NSString *path, BOOL isDirectory);
NSString *ISEmojiForKind(NSString *kind);

// Busca la IPv4 de la Wi-Fi (en0) y, si no, cualquier IPv4 no loopback.
NSString *ISLanIPv4Address(void);

// Quita separadores de ruta y caracteres de control de un nombre recibido.
NSString *ISSafeFileName(NSString *name);

// Devuelve una ruta libre dentro de directory: "foto.jpg", "foto (2).jpg"...
NSString *ISUniquePath(NSString *directory, NSString *fileName);

BOOL ISEnsureDirectory(NSString *path, NSError **error);

// "/sub/archivo.txt" para fullPath dentro de rootPath; nil si se sale.
NSString *ISRelativePath(NSString *fullPath, NSString *rootPath);

// Resuelve una ruta relativa ("/a/b") dentro de rootPath sin permitir escapes.
NSString *ISResolvePath(NSString *relativePath, NSString *rootPath);
