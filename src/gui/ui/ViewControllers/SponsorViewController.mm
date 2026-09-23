// SponsorViewController.mm
#import "SponsorViewController.h"
#import <ui/Categories/UIView+CardStyle.h>
#include <core/cfg.h>

@implementation SponsorViewController { UIScrollView *_scrollView; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = a1gui::locale("sponsor");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 24;
    mainStack.alignment = UIStackViewAlignmentFill;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:mainStack];
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-20],
        [mainStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:30],
        [mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-40],
        [mainStack.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-40]
    ]];
    UIView *logoCard = [self createLogoCard];
    [mainStack addArrangedSubview:logoCard];
    UIView *sponsorCard = [self createSponsorCard];
    [mainStack addArrangedSubview:sponsorCard];
}

- (UIView *)createLogoCard {
    UIView *card = [[UIView alloc] init];
    [card applyCardStyle];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:30],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-30]
    ]];
    UIImageView *heartIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart.fill"]];
    heartIcon.tintColor = [UIColor systemRedColor];
    heartIcon.contentMode = UIViewContentModeScaleAspectFit;
    [heartIcon.widthAnchor constraintEqualToConstant:70].active = YES;
    [heartIcon.heightAnchor constraintEqualToConstant:70].active = YES;
    [stack addArrangedSubview:heartIcon];
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = a1gui::locale("support_a1");
    titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightHeavy];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:titleLabel];
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = a1gui::locale("sponsor_text");
    descLabel.font = [UIFont systemFontOfSize:15];
    descLabel.textColor = [UIColor secondaryLabelColor];
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.numberOfLines = 0;
    [stack addArrangedSubview:descLabel];
    return card;
}

- (UIView *)createSponsorCard {
    UIView *card = [[UIView alloc] init];
    [card applyCardStyle];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    //stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-24]
    ]];
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 16;
    row.alignment = UIStackViewAlignmentCenter;
    [stack addArrangedSubview:row];
    UIButton *btn = [UIButton modernButtonWithTitle:a1gui::locale("go_to_ifdian_to_sponsor") color:[UIColor systemPinkColor]];
    [btn addTarget:self action:@selector(openAfdian) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:btn];
    return card;
}

- (void)openAfdian {
    NSURL *url = [NSURL URLWithString:@"https://ifdian.net/a/xmz-team"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) { [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil]; } else { [self copyLink]; }
}

- (void)copyLink {
    [[UIPasteboard generalPasteboard] setString:@"https://ifdian.net/a/xmz-team"];
    [self showAlert:a1gui::locale("link_has_been copied")];
}

- (void)showAlert:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:a1gui::locale("tips") message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:a1gui::locale("ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
