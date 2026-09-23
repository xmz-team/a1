// ConfigViewController.mm
#import "ConfigViewController.h"
#import <core/A1Executor.h>
#import <ui/Categories/UIView+CardStyle.h>
#include <core/cfg.h>

@implementation ConfigViewController { UITextView *_configTextView; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = a1gui::locale("config");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshConfig];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:scroll.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor constant:-40],
        [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor constant:-40]
    ]];
    NSArray *buttons = @[
        @[a1gui::locale("save_config"), @"saveConfig", [UIColor systemBlueColor]],
        @[a1gui::locale("restore_config"), @"restoreConfig", [UIColor systemOrangeColor]]
    ];
    UIStackView *btnGrid = [[UIStackView alloc] init];
    btnGrid.axis = UILayoutConstraintAxisVertical;
    btnGrid.spacing = 12;
    for (NSArray *item in buttons) {
        UIButton *btn = [UIButton modernButtonWithTitle:item[0] color:item[2]];
        [btn addTarget:self action:NSSelectorFromString(item[1]) forControlEvents:UIControlEventTouchUpInside];
        [btnGrid addArrangedSubview:btn];
    }
    [stack addArrangedSubview:btnGrid];
    UIView *textCard = [[UIView alloc] init];
    [textCard applyCardStyle];
    [stack addArrangedSubview:textCard];
    _configTextView = [[UITextView alloc] init];
    _configTextView.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
    _configTextView.backgroundColor = [UIColor clearColor];
    _configTextView.textColor = [UIColor labelColor];
    _configTextView.editable = NO;
    _configTextView.translatesAutoresizingMaskIntoConstraints = NO;
    [textCard addSubview:_configTextView];
    [NSLayoutConstraint activateConstraints:@[
        [_configTextView.leadingAnchor constraintEqualToAnchor:textCard.leadingAnchor constant:16],
        [_configTextView.trailingAnchor constraintEqualToAnchor:textCard.trailingAnchor constant:-16],
        [_configTextView.topAnchor constraintEqualToAnchor:textCard.topAnchor constant:16],
        [_configTextView.bottomAnchor constraintEqualToAnchor:textCard.bottomAnchor constant:-16],
        [_configTextView.heightAnchor constraintGreaterThanOrEqualToConstant:280]
    ]];
}

- (void)refreshConfig {
    _configTextView.text = [[A1Executor shared] getConfigContent];
}

- (void)saveConfig {
    [[A1Executor shared] saveConfig];
    [self showAlert:a1gui::locale("already_save_config")];
}

- (void)restoreConfig {
    [[A1Executor shared] restoreConfig];
    [self refreshConfig];
    [self showAlert:a1gui::locale("already_restore_config")];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:a1gui::locale("tips") message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:a1gui::locale("ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
