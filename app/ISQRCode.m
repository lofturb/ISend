#import "ISQRCode.h"
#import <CoreImage/CoreImage.h>

@implementation ISQRCode

+ (UIImage *)imageForString:(NSString *)string size:(CGFloat)size {
    if (!string.length || size <= 0) { return nil; }

    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if (!filter) { return nil; }
    [filter setDefaults];
    [filter setValue:[string dataUsingEncoding:NSUTF8StringEncoding]
              forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];

    CIImage *output = filter.outputImage;
    if (!output) { return nil; }

    CGRect extent = output.extent;
    if (extent.size.width <= 0) { return nil; }

    // El QR se dibuja en blanco con un margen de silencio del 8 %.
    CGFloat margin = size * 0.08;
    CGFloat side = size - margin * 2.0;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, size, size));
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextSetShouldAntialias(context, NO);

    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CGImageRef image = [ciContext createCGImage:output fromRect:extent];
    if (image) {
        CGContextDrawImage(context, CGRectMake(margin, margin, side, side), image);
        CGImageRelease(image);
    }

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@end
