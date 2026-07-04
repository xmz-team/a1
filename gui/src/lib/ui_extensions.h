/*
 * ui_extensions.h
 * Created by XMZ <ad-ios334@outlook.com> on 10/3/26
 * Copyright (c) 2025-2026 XMZ <ad-ios334@outlook.com> All rights reserved.
 */

#ifndef A1_GUI_UIEXTENSIONS_H
#define A1_GUI_UIEXTENSIONS_H
#pragma mark - Aesthetic UI Extensions

@interface UIView (Aesthetic)
- (void)applyCardStyle;
- (void)applySoftShadow;
@end

@implementation UIView (Aesthetic)
- (void)applyCardStyle {
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 20;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }
    
    for (UIView *sub in self.subviews) {
        if (sub.tag == 9990) [sub removeFromSuperview];
    }
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:blur];
    effectView.frame = self.bounds;
    effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    effectView.layer.cornerRadius = 20;
    effectView.clipsToBounds = YES;
    if (@available(iOS 13.0, *)) {
        effectView.layer.cornerCurve = kCACornerCurveContinuous;
    }
    effectView.tag = 9990;
    
    [self insertSubview:effectView atIndex:0];
    [self applySoftShadow];
}
- (void)applySoftShadow {
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.08;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 12;
}
@end

@interface UIButton (ModernStyle)
+ (instancetype)modernButtonWithTitle:(NSString *)title;
@end

@implementation UIButton (ModernStyle)
+ (instancetype)modernButtonWithTitle:(NSString *)title {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemBlueColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    btn.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) {
        btn.layer.cornerCurve = kCACornerCurveContinuous;
    }
    [btn.heightAnchor constraintEqualToConstant:50].active = YES;
    
    btn.layer.shadowColor = [UIColor systemBlueColor].CGColor;
    btn.layer.shadowOpacity = 0.25;
    btn.layer.shadowOffset = CGSizeMake(0, 4);
    btn.layer.shadowRadius = 8;
    return btn;
}
@end
#endif // A1_GUI_UIEXTENSIONS_H
