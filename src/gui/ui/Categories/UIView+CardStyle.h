// UIView+CardStyle.h
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (CardStyle)
- (void)applyCardStyle;
- (void)applySoftShadow;
@end

@interface UIButton (ModernStyle)
+ (instancetype)modernButtonWithTitle:(NSString *)title;
+ (instancetype)modernButtonWithTitle:(NSString *)title color:(UIColor *)color;
@end

NS_ASSUME_NONNULL_END
