// StatusViewController.mm
#import "StatusViewController.h"
#import <core/A1Executor.h>
#import <ui/Categories/UIView+CardStyle.h>
#import <core/env.h>
#include <string>
#include <core/cfg.h>

@implementation StatusViewController {
    UIImageView *_statusIcon;
    UILabel *_statusLabel;
    UILabel *_statusDescLabel;
    UIStackView *_featuresStack;
    UILabel *_featuresTitle;
    UIRefreshControl *_refreshControl;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = a1gui::locale("state");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
    [self setupRefreshControl];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshStatus];
}

- (void)setupRefreshControl {
    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(refreshStatus) forControlEvents:UIControlEventValueChanged];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.refreshControl = _refreshControl;
    [self.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    UIStackView *mainStack = [[UIStackView alloc] init];
    mainStack.axis = UILayoutConstraintAxisVertical;
    mainStack.spacing = 20;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:mainStack];
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-20],
        [mainStack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:24],
        [mainStack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-40],
        [mainStack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-40]
    ]];
    UIView *statusCard = [self createStatusCard];
    [mainStack addArrangedSubview:statusCard];
    UIView *featuresCard = [self createFeaturesCard];
    [mainStack addArrangedSubview:featuresCard];
    UIStackView *buttonGrid = [self createButtonGrid];
    [mainStack addArrangedSubview:buttonGrid];
}

- (UIView *)createStatusCard {
    UIView *card = [[UIView alloc] init];
    [card applyCardStyle];
    UIStackView *vStack = [[UIStackView alloc] init];
    vStack.axis = UILayoutConstraintAxisVertical;
    vStack.spacing = 12;
    vStack.alignment = UIStackViewAlignmentCenter;
    vStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:vStack];
    [NSLayoutConstraint activateConstraints:@[
        [vStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:32],
        [vStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-32],
        [vStack.centerXAnchor constraintEqualToAnchor:card.centerXAnchor]
    ]];
    _statusIcon = [[UIImageView alloc] init];
    [_statusIcon.widthAnchor constraintEqualToConstant:64].active = YES;
    [_statusIcon.heightAnchor constraintEqualToConstant:64].active = YES;
    _statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightHeavy];
    _statusDescLabel = [[UILabel alloc] init];
    _statusDescLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _statusDescLabel.textColor = [UIColor secondaryLabelColor];
    [vStack addArrangedSubview:_statusIcon];
    [vStack addArrangedSubview:_statusLabel];
    [vStack addArrangedSubview:_statusDescLabel];
    return card;
}

- (UIView *)createFeaturesCard {
    UIView *card = [[UIView alloc] init];
    [card applyCardStyle];
    _featuresStack = [[UIStackView alloc] init];
    _featuresStack.axis = UILayoutConstraintAxisVertical;
    _featuresStack.spacing = 16;
    _featuresStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:_featuresStack];
    [NSLayoutConstraint activateConstraints:@[
        [_featuresStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [_featuresStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [_featuresStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [_featuresStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20]
    ]];
    _featuresTitle = [[UILabel alloc] init];
    _featuresTitle.text = a1gui::locale("current_operating_mode");
    _featuresTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [_featuresStack addArrangedSubview:_featuresTitle];
    return card;
}

- (UIStackView *)createButtonGrid {
    UIStackView *grid = [[UIStackView alloc] init];
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 16;
    NSArray *buttons = @[
        @[a1gui::locale("start_a1"), @"startA1",   [UIColor systemBlueColor]],
        @[a1gui::locale("stop_a1"), @"stopA1",    [UIColor systemRedColor]],
        @[a1gui::locale("restart_a1"), @"restartA1", [UIColor systemOrangeColor]],
        @[a1gui::locale("return_priority"), @"returnPriority", [UIColor systemGreenColor]]
    ];
    for (NSArray *item in buttons) {
        UIButton *btn = [UIButton modernButtonWithTitle:item[0] color:item[2]];
        [btn addTarget:self action:NSSelectorFromString(item[1]) forControlEvents:UIControlEventTouchUpInside];
        [grid addArrangedSubview:btn];
    }
    return grid;
}

- (void)refreshStatus {
    bool running = [[A1Executor shared] isA1Running];
    if (running) {
        _statusIcon.image = [UIImage systemImageNamed:@"checkmark.shield.fill"];
        _statusIcon.tintColor = [UIColor systemGreenColor];
        _statusLabel.text = a1gui::locale("a1_is_running");
        _statusLabel.textColor = [UIColor systemGreenColor];
        _statusDescLabel.text = [NSString stringWithFormat:@"%@:%s", a1gui::locale("current_jailbreak"), g_env.get_jb_env().c_str()];
    } else {
        _statusIcon.image = [UIImage systemImageNamed:@"xmark.shield.fill"];
        _statusIcon.tintColor = [UIColor systemRedColor];
        _statusLabel.text = a1gui::locale("a1_not_running");
        _statusLabel.textColor = [UIColor systemRedColor];
        _statusDescLabel.text = [NSString stringWithFormat:@"%@:%s", a1gui::locale("current_jailbreak"), g_env.get_jb_env().c_str()];
    }
    // list of update modes
    for (UIView *sub in _featuresStack.arrangedSubviews) { if (sub != _featuresTitle) { [sub removeFromSuperview]; } }
    NSDictionary *modes = [[A1Executor shared] currentModeStatus];
    BOOL hasActive = NO;
    for (NSInteger i = 0; i < 9; i++) {
        NSString *key = kA1ModeKeys[i];
        if ([modes[key] isEqualToString:@"on"]) {
            hasActive = YES;
            UIStackView *row = [[UIStackView alloc] init];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 12;
            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:kA1ModeIcons[i]]];
            icon.tintColor = [UIColor systemBlueColor];
            [icon.widthAnchor constraintEqualToConstant:22].active = YES;
            [icon.heightAnchor constraintEqualToConstant:22].active = YES;
            UILabel *nameLabel = [[UILabel alloc] init];
            nameLabel.text = kA1ModeDisplayNames[i];
            nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            [row addArrangedSubview:icon];
            [row addArrangedSubview:nameLabel];
            UIView *spacer = [[UIView alloc] init];
            [row addArrangedSubview:spacer];
            [_featuresStack addArrangedSubview:row];
        }
    }
    if (!hasActive) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = a1gui::locale("no_mode_is_enabled_at_present");
        emptyLabel.font = [UIFont systemFontOfSize:14];
        emptyLabel.textColor = [UIColor secondaryLabelColor];
        [_featuresStack addArrangedSubview:emptyLabel];
    }
    [_refreshControl endRefreshing];
}

- (void)startA1 {
    [[A1Executor shared] startA1];
    [self refreshStatus];
}

- (void)stopA1 {
    [[A1Executor shared] stopA1];
    [self refreshStatus];
}

- (void)restartA1 {
    [[A1Executor shared] restartA1];
    [self refreshStatus];
}

- (void)returnPriority {
    [[A1Executor shared] returnPriority];
    [self refreshStatus];
}
@end
