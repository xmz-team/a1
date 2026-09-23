// ModuleViewController.mm
#import "ModuleViewController.h"
#import <core/A1Executor.h>
#import <ui/Categories/UIView+CardStyle.h>
#include <core/cfg.h>

@implementation ModuleViewController {
    UITableView *_tableView;
    NSArray<NSString *> *_modules;
    UIRefreshControl *_refreshControl;
    UISwitch *_globalSwitch;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = a1gui::locale("module_system");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modeStatusChanged:) name:@"A1ModeStatusChangedNotification" object:nil];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshGlobalSwitch];
    [self loadModules];
}

- (void)modeStatusChanged:(NSNotification *)note {
    if (note.object == self) return;
    NSString *key = note.userInfo[@"key"];
    if ([key isEqualToString:@"module"]) dispatch_async(dispatch_get_main_queue(), ^{[self refreshGlobalSwitch];});
}

- (void)refreshGlobalSwitch {
    NSDictionary *modes = [[A1Executor shared] currentModeStatus];
    _globalSwitch.on = [modes[@"module_switch"] isEqualToString:@"on"];
}

- (void)setupUI {
    UIView *topCard = [[UIView alloc] init];
    [topCard applyCardStyle];
    topCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:topCard];
    UIStackView *topStack = [[UIStackView alloc] init];
    topStack.axis = UILayoutConstraintAxisHorizontal;
    topStack.alignment = UIStackViewAlignmentCenter;
    topStack.translatesAutoresizingMaskIntoConstraints = NO;
    [topCard addSubview:topStack];
    UILabel *label = [[UILabel alloc] init];
    label.text = a1gui::locale("enable_module_system");
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _globalSwitch = [[UISwitch alloc] init];
    [_globalSwitch addTarget:self action:@selector(globalSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [topStack addArrangedSubview:_globalSwitch];
    UISwitch *gs = _globalSwitch;
    NSDictionary *modes = [[A1Executor shared] currentModeStatus];
    gs.on = [modes[@"module_switch"] isEqualToString:@"on"];
    [topStack addArrangedSubview:label];
    [topStack addArrangedSubview:gs];
    [NSLayoutConstraint activateConstraints:@[
        [topStack.leadingAnchor constraintEqualToAnchor:topCard.leadingAnchor constant:20],
        [topStack.trailingAnchor constraintEqualToAnchor:topCard.trailingAnchor constant:-20],
        [topStack.topAnchor constraintEqualToAnchor:topCard.topAnchor constant:16],
        [topStack.bottomAnchor constraintEqualToAnchor:topCard.bottomAnchor constant:-16]
    ]];
    UIStackView *btnStack = [[UIStackView alloc] init];
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.spacing = 16;
    btnStack.distribution = UIStackViewDistributionFillEqually;
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:btnStack];
    UIButton *btnInstall = [UIButton modernButtonWithTitle:a1gui::locale("import") color:[UIColor systemBlueColor]];
    [btnInstall addTarget:self action:@selector(installModule) forControlEvents:UIControlEventTouchUpInside];
    UIButton *btnLoad = [UIButton modernButtonWithTitle:a1gui::locale("load") color:[UIColor systemGreenColor]];
    [btnLoad addTarget:self action:@selector(loadModulesAction) forControlEvents:UIControlEventTouchUpInside];
    [btnStack addArrangedSubview:btnInstall];
    [btnStack addArrangedSubview:btnLoad];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor clearColor];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(loadModules) forControlEvents:UIControlEventValueChanged];
    _tableView.refreshControl = _refreshControl;
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [topCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [topCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [topCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [btnStack.topAnchor constraintEqualToAnchor:topCard.bottomAnchor constant:20],
        [btnStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [btnStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_tableView.topAnchor constraintEqualToAnchor:btnStack.bottomAnchor constant:16],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)globalSwitchChanged:(UISwitch *)sender { [[A1Executor shared] setMode:A1ModeModule on:sender.on]; }

- (void)loadModules {
    _modules = [[A1Executor shared] moduleList];
    [_tableView reloadData];
    [_refreshControl endRefreshing];
}

- (void)installModule {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.archive"] inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)loadModulesAction {
    [[A1Executor shared] loadModules];
    [self loadModules];
}

#pragma mark - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [[A1Executor shared] moduleInstall:urls.firstObject.path];
    [self loadModules];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _modules.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.textLabel.text = _modules[indexPath.row];
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[A1Executor shared] moduleRemove:_modules[indexPath.row]];
        [self loadModules];
    }
}
@end
