#import "ISAppDelegate.h"
#import "ISTheme.h"
#import "ISService.h"
#import "ISHomeViewController.h"
#import "ISFilesViewController.h"

static UIImage *ISTabIcon(void (^draw)(CGContextRef context, CGSize size)) {
    CGSize size = CGSizeMake(26.0, 26.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(context, 2.0);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    if (draw) { draw(context, size); }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@implementation ISAppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [ISTheme applyAppearance];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [ISTheme background];
    self.window.tintColor = [ISTheme accent];

    ISHomeViewController *home = [[ISHomeViewController alloc] init];
    UINavigationController *homeNav =
        [[UINavigationController alloc] initWithRootViewController:home];
    homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Compartir"
                                                       image:ISTabIcon(^(CGContextRef ctx, CGSize size) {
        CGContextMoveToPoint(ctx, 9.0, 21.0);
        CGContextAddLineToPoint(ctx, 9.0, 6.0);
        CGContextMoveToPoint(ctx, 5.0, 10.0);
        CGContextAddLineToPoint(ctx, 9.0, 6.0);
        CGContextAddLineToPoint(ctx, 13.0, 10.0);
        CGContextMoveToPoint(ctx, 17.0, 5.0);
        CGContextAddLineToPoint(ctx, 17.0, 20.0);
        CGContextMoveToPoint(ctx, 13.0, 16.0);
        CGContextAddLineToPoint(ctx, 17.0, 20.0);
        CGContextAddLineToPoint(ctx, 21.0, 16.0);
        CGContextStrokePath(ctx);
    }) tag:0];

    ISFilesViewController *files = [[ISFilesViewController alloc] initWithRelativePath:@"/"];
    UINavigationController *filesNav =
        [[UINavigationController alloc] initWithRootViewController:files];
    filesNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Archivos"
                                                       image:ISTabIcon(^(CGContextRef ctx, CGSize size) {
        CGContextMoveToPoint(ctx, 3.0, 21.0);
        CGContextAddLineToPoint(ctx, 3.0, 8.0);
        CGContextAddLineToPoint(ctx, 10.0, 8.0);
        CGContextAddLineToPoint(ctx, 13.0, 11.0);
        CGContextAddLineToPoint(ctx, 23.0, 11.0);
        CGContextAddLineToPoint(ctx, 23.0, 21.0);
        CGContextClosePath(ctx);
        CGContextStrokePath(ctx);
    }) tag:1];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[ homeNav, filesNav ];
    tabs.tabBar.translucent = NO;
    tabs.tabBar.barTintColor = [ISTheme card];

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];

    ISService *service = [ISService shared];
    if (service.serverEnabled) {
        [service startWithError:NULL];
    }

    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[ISService shared] suspendForBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    [[ISService shared] resumeAfterForeground];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[ISService shared] suspendForBackground];
}

@end
