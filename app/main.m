#import <UIKit/UIKit.h>
#import <signal.h>
#import "ISAppDelegate.h"

int main(int argc, char *argv[]) {
    // Escribir en un socket que el cliente ya cerro no debe matar la app.
    signal(SIGPIPE, SIG_IGN);
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([ISAppDelegate class]));
    }
}
