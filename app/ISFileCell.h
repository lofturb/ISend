#import <UIKit/UIKit.h>

@interface ISFileCell : UITableViewCell

- (void)configureWithName:(NSString *)name
                   detail:(NSString *)detail
                    emoji:(NSString *)emoji
                   folder:(BOOL)folder;

@end
