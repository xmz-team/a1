// PriorityViewController.mm
#import "PriorityViewController.h"
#import <core/A1Executor.h>
#import <core/A1Constants.h>
#import <ui/Categories/UIView+CardStyle.h>
#include <core/cfg.h>

@implementation PriorityViewController {
    UISegmentedControl *_segmented;
    UITableView *_tableView;
    NSArray<NSString *> *_dataSource;
    NSDictionary<NSString *, NSString *> *_customMap;
    A1PriorityType _currentType;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = a1gui::locale("course");
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    _currentType = A1PriorityHigh;
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadData];
}

- (void)setupUI {
    _segmented = [[UISegmentedControl alloc] initWithItems:@[a1gui::locale("high_priority"), a1gui::locale("low_priority"), a1gui::locale("customization")]];
    _segmented.selectedSegmentIndex = 0;
    [_segmented addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];
    _segmented.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_segmented];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor clearColor];
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_segmented.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [_segmented.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_segmented.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_tableView.topAnchor constraintEqualToAnchor:_segmented.bottomAnchor constant:16],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem)];
}

- (void)segmentChanged {
    _currentType = (A1PriorityType)_segmented.selectedSegmentIndex;
    [self loadData];
}

- (void)loadData {
    if (_currentType == A1PriorityCustom) {
        _customMap = [[A1Executor shared] customPriorityMap];
        _dataSource = _customMap.allKeys;
    } else {
       _dataSource = [[A1Executor shared] priorityListForType:_currentType];
    }
    [_tableView reloadData];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _dataSource.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    NSString *proc = _dataSource[indexPath.row];
    if (_currentType == A1PriorityCustom) { cell.textLabel.text = [NSString stringWithFormat:@"%@ = %@", proc, _customMap[proc]]; } else { cell.textLabel.text = proc; }
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[A1Executor shared] removePriority:_dataSource[indexPath.row]];
        [self loadData];
    }
}

#pragma mark - add
- (void)addItem {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:a1gui::locale("config_process") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = a1gui::locale("enter_process_name");
    }];
    if (_currentType == A1PriorityCustom) {
        [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = a1gui::locale("priority (0-99)");
            tf.keyboardType = UIKeyboardTypeNumberPad;
        }];
    }
    [alert addAction:[UIAlertAction actionWithTitle:a1gui::locale("certain") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *nameField = alert.textFields.firstObject;
        if (nameField.text.length > 0) {
            NSString *value = alert.textFields.count > 1 ? alert.textFields[1].text : nil;
            [[A1Executor shared] addPriority:nameField.text type:_currentType value:value];
            [self loadData];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:a1gui::locale("cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
