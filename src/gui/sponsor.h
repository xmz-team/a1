/*
 * sponsor.h
 * Created by XMZ <xmz-team@outlook.com> on 10/3/26
 * Copyright (c) 2026 XMZ <xmz-team@outlook.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see
 * <https://www.gnu.org/licenses/lgpl-3.0.html>.
 */

#ifndef A1_GUI_SPONSOR_HPP
#define A1_GUI_SPONSOR_HPP

#import <UIKit/UIKit.h>
#include <libxmz/apple-ios-ui.hpp>
#include <libxmz/log.hpp>

@implementation UIView (SponsorCardStyle)
- (void)applyCardStyle {
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 20;
    if (@available(iOS 13.0, *)) {
        self.layer.cornerCurve = kCACornerCurveContinuous;
    }

    for (UIView *sub in self.subviews) {
        if (sub.tag == 8888) [sub removeFromSuperview];
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
    effectView.tag = 8888;
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

@implementation UIButton (SponsorButtonStyle)
+ (instancetype)modernButtonWithTitle:(NSString *)title {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = [UIColor systemBlueColor];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    button.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) {
        button.layer.cornerCurve = kCACornerCurveContinuous;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    button.contentEdgeInsets = UIEdgeInsetsMake(14, 24, 14, 24);
#pragma clang diagnostic pop
    button.layer.shadowColor = [UIColor systemBlueColor].CGColor;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    button.layer.shadowOpacity = 0.3;
    button.layer.shadowRadius = 8;
    [button.heightAnchor constraintEqualToConstant:50].active = YES;
    
    return button;
}
@end

#pragma mark - SponsorViewController (赞助页面)
@interface SponsorViewController : UIViewController
@end

@implementation SponsorViewController {
    UIScrollView *_scrollView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"赞助支持";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];
    xmz::ui::layout::fill(_scrollView, self.view);
    
    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 24;
    mainStack.alignment = UIStackViewAlignmentFill;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:mainStack];
    [mainStack.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:20].active = YES;
    [mainStack.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-20].active = YES;
    [mainStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:30].active = YES;
    [mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-40].active = YES;
    [mainStack.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-40].active = YES;
    
    // Logo/头像卡片
    UIView *logoCard = [[UIView alloc] init];
    [logoCard applyCardStyle];
    [mainStack addArrangedSubview:logoCard];
    
    UIStackView *logoStack = [[UIStackView alloc] init];
    logoStack.axis = UILayoutConstraintAxisVertical;
    logoStack.spacing = 16;
    logoStack.alignment = UIStackViewAlignmentCenter;
    logoStack.translatesAutoresizingMaskIntoConstraints = NO;
    [logoCard addSubview:logoStack];
    [logoStack.leadingAnchor constraintEqualToAnchor:logoCard.leadingAnchor constant:24].active = YES;
    [logoStack.trailingAnchor constraintEqualToAnchor:logoCard.trailingAnchor constant:-24].active = YES;
    [logoStack.topAnchor constraintEqualToAnchor:logoCard.topAnchor constant:30].active = YES;
    [logoStack.bottomAnchor constraintEqualToAnchor:logoCard.bottomAnchor constant:-30].active = YES;

    UIImageView *heartIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill"]];
    heartIcon.tintColor = [UIColor systemRedColor];
    heartIcon.contentMode = UIViewContentModeScaleAspectFit;
    [heartIcon.widthAnchor constraintEqualToConstant:70].active = YES;
    [heartIcon.heightAnchor constraintEqualToConstant:70].active = YES;
    
    // 心形图标添加柔和发光阴影
    heartIcon.layer.shadowColor = [UIColor systemRedColor].CGColor;
    heartIcon.layer.shadowOffset = CGSizeMake(0, 4);
    heartIcon.layer.shadowOpacity = 0.4;
    heartIcon.layer.shadowRadius = 12;
    [logoStack addArrangedSubview:heartIcon];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"支持 A1 项目";
    titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightHeavy];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [logoStack addArrangedSubview:titleLabel];
    
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"您的每一次支持，都是项目持续进化的核心动力。";
    descLabel.font = [UIFont systemFontOfSize:15];
    descLabel.textColor = [UIColor secondaryLabelColor];
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.numberOfLines = 0;
    [logoStack addArrangedSubview:descLabel];
    
    // 赞助方式卡片 - 爱发电
    UIView *sponsorCard = [[UIView alloc] init];
    [sponsorCard applyCardStyle];
    [mainStack addArrangedSubview:sponsorCard];
    
    UIStackView *sponsorStack = [[UIStackView alloc] init];
    sponsorStack.axis = UILayoutConstraintAxisVertical;
    sponsorStack.spacing = 20;
    sponsorStack.translatesAutoresizingMaskIntoConstraints = NO;
    [sponsorCard addSubview:sponsorStack];
    [sponsorStack.leadingAnchor constraintEqualToAnchor:sponsorCard.leadingAnchor constant:20].active = YES;
    [sponsorStack.trailingAnchor constraintEqualToAnchor:sponsorCard.trailingAnchor constant:-20].active = YES;
    [sponsorStack.topAnchor constraintEqualToAnchor:sponsorCard.topAnchor constant:24].active = YES;
    [sponsorStack.bottomAnchor constraintEqualToAnchor:sponsorCard.bottomAnchor constant:-24].active = YES;
    
    UIStackView *afdianRow = [[UIStackView alloc] init];
    afdianRow.axis = UILayoutConstraintAxisHorizontal;
    afdianRow.spacing = 16;
    afdianRow.alignment = UIStackViewAlignmentCenter;
    
    UIView *iconContainer = [[UIView alloc] init];
    iconContainer.backgroundColor = [[UIColor systemPinkColor] colorWithAlphaComponent:0.15];
    iconContainer.layer.cornerRadius = 12;
    if (@available(iOS 13.0, *)) { iconContainer.layer.cornerCurve = kCACornerCurveContinuous; }
    [iconContainer.widthAnchor constraintEqualToConstant:48].active = YES;
    [iconContainer.heightAnchor constraintEqualToConstant:48].active = YES;
    
    UIImageView *afdianIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bolt.heart.fill"]];
    afdianIcon.tintColor = [UIColor systemPinkColor];
    afdianIcon.contentMode = UIViewContentModeScaleAspectFit;
    afdianIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [iconContainer addSubview:afdianIcon];
    [afdianIcon.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor].active = YES;
    [afdianIcon.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor].active = YES;
    [afdianIcon.widthAnchor constraintEqualToConstant:28].active = YES;
    [afdianIcon.heightAnchor constraintEqualToConstant:28].active = YES;
    
    UIStackView *afdianTextStack = [[UIStackView alloc] init];
    afdianTextStack.axis = UILayoutConstraintAxisVertical;
    afdianTextStack.spacing = 4;
    
    UILabel *afdianLabel = [[UILabel alloc] init];
    afdianLabel.text = @"爱发电 (ifdian)";
    afdianLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    
    UILabel *afdianDesc = [[UILabel alloc] init];
    afdianDesc.text = @"推荐使用此平台赞助开发";
    afdianDesc.font = [UIFont systemFontOfSize:14];
    afdianDesc.textColor = [UIColor secondaryLabelColor];
    
    [afdianTextStack addArrangedSubview:afdianLabel];
    [afdianTextStack addArrangedSubview:afdianDesc];
    
    [afdianRow addArrangedSubview:iconContainer];
    [afdianRow addArrangedSubview:afdianTextStack];
    [sponsorStack addArrangedSubview:afdianRow];
    
    UIButton *afdianBtn = [UIButton modernButtonWithTitle:@"前往爱发电赞助"];
    afdianBtn.backgroundColor = [UIColor systemPinkColor];
    afdianBtn.layer.shadowColor = [UIColor systemPinkColor].CGColor;
    [afdianBtn addTarget:self action:@selector(openAfdian) forControlEvents:UIControlEventTouchUpInside];
    [sponsorStack addArrangedSubview:afdianBtn];
    
    // 链接复制区域
    UIView *linkCard = [[UIView alloc] init];
    [linkCard applyCardStyle];
    [mainStack addArrangedSubview:linkCard];
    
    UIStackView *linkStack = [[UIStackView alloc] init];
    linkStack.axis = UILayoutConstraintAxisHorizontal;
    linkStack.spacing = 16;
    linkStack.alignment = UIStackViewAlignmentCenter;
    linkStack.translatesAutoresizingMaskIntoConstraints = NO;
    [linkCard addSubview:linkStack];
    [linkStack.leadingAnchor constraintEqualToAnchor:linkCard.leadingAnchor constant:20].active = YES;
    [linkStack.trailingAnchor constraintEqualToAnchor:linkCard.trailingAnchor constant:-20].active = YES;
    [linkStack.topAnchor constraintEqualToAnchor:linkCard.topAnchor constant:16].active = YES;
    [linkStack.bottomAnchor constraintEqualToAnchor:linkCard.bottomAnchor constant:-16].active = YES;
    
    UIImageView *linkIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"link"]];
    linkIcon.tintColor = [UIColor secondaryLabelColor];
    [linkIcon.widthAnchor constraintEqualToConstant:24].active = YES;
    [linkIcon.heightAnchor constraintEqualToConstant:24].active = YES;
    [linkStack addArrangedSubview:linkIcon];
    
    UILabel *urlLabel = [[UILabel alloc] init];
    urlLabel.text = @"ifdian.net/a/xmz-team";
    urlLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    urlLabel.textColor = [UIColor systemBlueColor];
    urlLabel.numberOfLines = 0;
    [linkStack addArrangedSubview:urlLabel];
    
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyBtn setImage:[UIImage systemImageNamed:@"doc.on.doc.fill"] forState:UIControlStateNormal];
    copyBtn.tintColor = [UIColor systemBlueColor];
    [copyBtn addTarget:self action:@selector(copyLink:) forControlEvents:UIControlEventTouchUpInside];
    [copyBtn.widthAnchor constraintEqualToConstant:40].active = YES;
    [copyBtn.heightAnchor constraintEqualToConstant:40].active = YES;
    [linkStack addArrangedSubview:copyBtn];
}

- (void)openAfdian {
    NSString *urlString = @"https://ifdian.net/a/xmz-team";
    NSURL *url = [NSURL URLWithString:urlString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
            if (!success) {
                [self showAlert:@"无法打开链接，请手动复制链接到浏览器"];
								xmz::log::warn("open url failed");
            }
        }];
    } else {
        [self copyLink:nil];
        [self showAlert:@"已复制链接到剪贴板，请手动粘贴到浏览器打开"];
				xmz::log::info("url copied to clipboard successfully");
    }
}

- (void)copyLink:(id)sender {
    NSString *link = @"https://ifdian.net/a/xmz-team";
    [[UIPasteboard generalPasteboard] setString:link];
    [self showAlert:@"链接已复制"];
		xmz::log::info("url copied");
}

- (void)showAlert:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#endif // A1_GUI_SPONSOR_HPP
