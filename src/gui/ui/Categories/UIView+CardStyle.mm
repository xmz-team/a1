// UIView+CardStyle.mm
#import "UIView+CardStyle.h"

@implementation UIView (CardStyle)
- (void)applyCardStyle {
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 20;
    if (@available(iOS 13.0, *)) self.layer.cornerCurve = kCACornerCurveContinuous;
    // remove the old blur view
    for (UIView *sub in self.subviews) { if ([sub isKindOfClass:[UIVisualEffectView class]]) { [sub removeFromSuperview]; } }
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:blur];
    effectView.frame = self.bounds;
    effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    effectView.layer.cornerRadius = 20;
    effectView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) effectView.layer.cornerCurve = kCACornerCurveContinuous;
    [self insertSubview:effectView atIndex:0];
    [self applySoftShadow];
}

- (void)applySoftShadow {
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 6);
    self.layer.shadowOpacity = 0.12;
    self.layer.shadowRadius = 16;
}
@end

@implementation UIButton (ModernStyle)
+ (instancetype)modernButtonWithTitle:(NSString *)title { return [self modernButtonWithTitle:title color:[UIColor systemBlueColor]]; }
+ (instancetype)modernButtonWithTitle:(NSString *)title color:(UIColor *)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = color;
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    button.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) button.layer.cornerCurve = kCACornerCurveContinuous;
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 24, 14, 24);
    button.layer.shadowColor = color.CGColor;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    button.layer.shadowOpacity = 0.3;
    button.layer.shadowRadius = 8;
    [button.heightAnchor constraintEqualToConstant:50].active = YES;
    return button;
}
@end
