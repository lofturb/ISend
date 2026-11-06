#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Paleta y tipografia unicas de la app. Tema oscuro para que combine con la
// interfaz web y para que el iPad mini (pantalla no retina) tenga contraste.
@interface ISTheme : NSObject

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha;
+ (UIColor *)background;
+ (UIColor *)card;
+ (UIColor *)cardAlt;
+ (UIColor *)separator;
+ (UIColor *)textPrimary;
+ (UIColor *)textSecondary;
+ (UIColor *)textTertiary;
+ (UIColor *)accent;
+ (UIColor *)accentDark;
+ (UIColor *)accentSoft;
+ (UIColor *)danger;
+ (UIColor *)warning;
+ (UIColor *)success;

+ (UIFont *)fontTitle;
+ (UIFont *)fontHeadline;
+ (UIFont *)fontBody;
+ (UIFont *)fontSubhead;
+ (UIFont *)fontCaption;
+ (UIFont *)fontMono:(CGFloat)size;

// Tarjeta con esquinas redondeadas y borde sutil.
+ (UIView *)cardView;

// Boton de color plano, sin depender de UIButtonConfiguration (no existe en iOS 9).
+ (UIButton *)buttonWithTitle:(NSString *)title
                   background:(UIColor *)background
                   foreground:(UIColor *)foreground;

// Aplica el aspecto oscuro a barras de navegacion y de pestanas.
+ (void)applyAppearance;

@end
