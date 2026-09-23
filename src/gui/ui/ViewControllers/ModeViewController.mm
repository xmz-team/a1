// ModeViewController.mm
#import <objc/runtime.h>
#import "ModeViewController.h"
#import <core/A1Executor.h>
#import <core/A1Constants.h>
#import <ui/Categories/UIView+CardStyle.h>
#include <core/cfg.h>

@implementation ModeViewController {
    UIScrollView *_scrollView;
    NSMutableDictionary<NSString *, UISwitch *> *_switches;
    NSMutableDictionary<NSString *, id> *_associatedObjects;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = a1gui::locale("function");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    _switches = [NSMutableDictionary dictionary];
    _associatedObjects = [NSMutableDictionary dictionary];
    [self setupUI];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modeStatusChanged:) name:@"A1ModeStatusChangedNotification" object:nil];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)modeStatusChanged:(NSNotification *)note {
    if (note.object == self) return;
    NSString *key = note.userInfo[@"key"];
    if (![key isEqualToString:@"module"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UISwitch *sw = self->_switches[@"module"];
        if (sw) {
            NSDictionary *modes = [[A1Executor shared] currentModeStatus];
            sw.on = [modes[@"module_switch"] isEqualToString:@"on"];
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadCurrentStates];
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
    mainStack.spacing = 16;
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:mainStack];
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-20],
        [mainStack.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:24],
        [mainStack.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-40],
        [mainStack.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-40]
    ]];
    for (NSInteger i = 0; i < 8; i++) {
        UIView *card = [self createModeCardWithKey:kA1ModeKeys[i]
                                             title:kA1ModeDisplayNames[i]
                                       description:kA1ModeDescriptions[i]];
        [mainStack addArrangedSubview:card];
    }
    [mainStack addArrangedSubview:[self createInputCardWithTitle:a1gui::locale("optimization_interval__s")
                                                      action:@selector(setInterval:)]];
    [mainStack addArrangedSubview:[self createInputCardWithTitle:a1gui::locale("cyclic_dormancy__s")
                                                      action:@selector(setLoopSleep:)]];
}

- (UIView *)createModeCardWithKey:(NSString *)key title:(NSString *)title description:(NSString *)desc {
    UIView *card = [[UIView alloc] init];
    [card applyCardStyle];
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = 16;
    hStack.alignment = UIStackViewAlignmentCenter;
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:hStack];
    [NSLayoutConstraint activateConstraints:@[
        [hStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [hStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [hStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [hStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18]
    ]];
    UIStackView *vStack = [[UIStackView alloc] init];
    vStack.axis = UILayoutConstraintAxisVertical;
    vStack.spacing = 6;
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = desc;
    descLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    descLabel.textColor = [UIColor secondaryLabelColor];
    descLabel.numberOfLines = 0;
    [vStack addArrangedSubview:titleLabel];
    [vStack addArrangedSubview:descLabel];
    UISwitch *sw = [[UISwitch alloc] init];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    _switches[key] = sw;
    [hStack addArrangedSubview:vStack];
    [hStack addArrangedSubview:sw];
    return card;
}

- (UIView *)createInputCardWithTitle:(NSString *)title action:(SEL)action {
    UIView *card = [[UIView alloc] init];
    [card applyCardStyle];
    UIStackView *hStack = [[UIStackView alloc] init];
    hStack.axis = UILayoutConstraintAxisHorizontal;
    hStack.spacing = 12;
    hStack.alignment = UIStackViewAlignmentCenter;
    hStack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:hStack];
    [NSLayoutConstraint activateConstraints:@[
        [hStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [hStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [hStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [hStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18]
    ]];
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [titleLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    UITextField *field = [[UITextField alloc] init];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = a1gui::locale("input_seconds");
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.delegate = self;
    [field setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:a1gui::locale("setup") forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemBlueColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 8;
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [btn.widthAnchor constraintEqualToConstant:60].active = YES;
    [btn.heightAnchor constraintEqualToConstant:34].active = YES;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    NSString *fieldKey = [NSString stringWithFormat:@"%@_field", title];
    _associatedObjects[fieldKey] = field;
    objc_setAssociatedObject(btn, "field", field, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [hStack addArrangedSubview:titleLabel];
    [hStack addArrangedSubview:field];
    [hStack addArrangedSubview:btn];
    return card;
}

- (void)loadCurrentStates {
    NSDictionary *modes = [[A1Executor shared] currentModeStatus];
    for (NSString *key in modes) { if (_switches[key]) { _switches[key].on = [modes[key] isEqualToString:@"on"]; } }
}

- (void)switchChanged:(UISwitch *)sender {
    for (NSString *key in _switches) {
        if (_switches[key] == sender) {
            for (NSInteger i = 0; i < 9; i++) {
                if ([key isEqualToString:kA1ModeKeys[i]]) {
                    [[A1Executor shared] setMode:(A1ModeKey)i on:sender.on];
                    break;
                }
            }
            break;
        }
    }
}

- (void)setInterval:(UIButton *)sender {
    UITextField *field = objc_getAssociatedObject(sender, "field");
    if (field.text.length > 0) {
        NSInteger val = [field.text integerValue];
        if (val > 0) {
            [[A1Executor shared] setOptimizeInterval:val];
            [self showAlert:a1gui::locale("successful_setting")];
        }
        field.text = @"";
        [field resignFirstResponder];
    }
}

- (void)setLoopSleep:(UIButton *)sender {
    UITextField *field = objc_getAssociatedObject(sender, "field");
    if (field.text.length > 0) {
        NSInteger val = [field.text integerValue];
        if (val > 0) {
            [[A1Executor shared] setLoopSleepInterval:val];
            [self showAlert:a1gui::locale("successful_setting")];
        }
        field.text = @"";
        [field resignFirstResponder];
    }
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:a1gui::locale("tips")
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:a1gui::locale("ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    CGPoint point = [textField convertPoint:CGPointZero toView:_scrollView];
    [_scrollView setContentOffset:CGPointMake(0, point.y - 100) animated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
@end
