#import "ISTheme.h"

@implementation ISTheme

#pragma mark - Colores

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    CGFloat r = ((hex >> 16) & 0xFF) / 255.0;
    CGFloat g = ((hex >> 8) & 0xFF) / 255.0;
    CGFloat b = (hex & 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
}

+ (UIColor *)background   { return [ISTheme colorWithHex:0x0B1220 alpha:1.0]; }
+ (UIColor *)card         { return [ISTheme colorWithHex:0x141D2E alpha:1.0]; }
+ (UIColor *)cardAlt      { return [ISTheme colorWithHex:0x1B2740 alpha:1.0]; }
+ (UIColor *)separator    { return [ISTheme colorWithHex:0x24314A alpha:1.0]; }
+ (UIColor *)textPrimary  { return [ISTheme colorWithHex:0xF2F6FF alpha:1.0]; }
+ (UIColor *)textSecondary{ return [ISTheme colorWithHex:0x93A2BF alpha:1.0]; }
+ (UIColor *)textTertiary { return [ISTheme colorWithHex:0x64748F alpha:1.0]; }
+ (UIColor *)accent       { return [ISTheme colorWithHex:0x3DDC97 alpha:1.0]; }
+ (UIColor *)accentDark   { return [ISTheme colorWithHex:0x1B9E6B alpha:1.0]; }
+ (UIColor *)accentSoft   { return [ISTheme colorWithHex:0x3DDC97 alpha:0.16]; }
+ (UIColor *)danger       { return [ISTheme colorWithHex:0xFF6B6B alpha:1.0]; }
+ (UIColor *)warning      { return [ISTheme colorWithHex:0xFFC15E alpha:1.0]; }
+ (UIColor *)success      { return [ISTheme colorWithHex:0x3DDC97 alpha:1.0]; }

#pragma mark - Tipografia

+ (UIFont *)fontTitle {
    return [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
}
+ (UIFont *)fontHeadline {
    return [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
}
+ (UIFont *)fontBody {
    return [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
}
+ (UIFont *)fontSubhead {
    return [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
}
+ (UIFont *)fontCaption {
    return [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
}
+ (UIFont *)fontMono:(CGFloat)size {
    UIFont *f = [UIFont fontWithName:@"Menlo" size:size];
    return f ?: [UIFont fontWithName:@"Courier" size:size];
}

#pragma mark - Componentes

+ (UIView *)cardView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [ISTheme card];
    view.layer.cornerRadius = 16.0;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [ISTheme separator].CGColor;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

+ (UIButton *)buttonWithTitle:(NSString *)title
                   background:(UIColor *)background
                   foreground:(UIColor *)foreground {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:foreground forState:UIControlStateNormal];
    button.backgroundColor = background;
    button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    button.layer.cornerRadius = 10.0;
    button.contentEdgeInsets = UIEdgeInsetsMake(11.0, 16.0, 11.0, 16.0);
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

+ (void)applyAppearance {
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;

    UINavigationBar *nav = [UINavigationBar appearance];
    nav.barTintColor = [ISTheme card];
    nav.translucent = NO;
    nav.tintColor = [ISTheme accent];
    nav.titleTextAttributes = @{
        NSForegroundColorAttributeName: [ISTheme textPrimary],
        NSFontAttributeName: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
    };

    UITabBar *tab = [UITabBar appearance];
    tab.barTintColor = [ISTheme card];
    tab.translucent = NO;
    tab.tintColor = [ISTheme accent];

    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [ISTheme accent]
    } forState:UIControlStateSelected];
    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [ISTheme textTertiary]
    } forState:UIControlStateNormal];
}

@end
