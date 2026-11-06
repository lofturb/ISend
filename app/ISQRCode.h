#import <UIKit/UIKit.h>

// Genera un codigo QR nitido con CoreImage (disponible desde iOS 7).
@interface ISQRCode : NSObject

+ (UIImage *)imageForString:(NSString *)string size:(CGFloat)size;

@end
