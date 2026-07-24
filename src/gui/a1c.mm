/*
 * a1c.mm
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#include <libxmz/io.hpp>
#include <libxmz/apple-ios-ui.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/runsh.hpp>
#include <libxmz/log.hpp>
#include <libxmz/aux.hpp>

#import "sponsor.h"
#import <objc/runtime.h>

#include <cstdlib>
#include <string>
#import <unistd.h>
#if defined(__roothide__)
		#include <roothide/roothide.h>
#endif

#pragma mark - Aesthetic UI Extensions // in sponsor.h

#pragma mark - Core Engine functions
std::string get_jbarch() {
    #if defined(__rootless__)
        return "iphoneos-arm64";
    #elif defined(__roothide__)
        return "iphoneos-arm64e";
    #else
        return xmz::cmd::runbash("[ -f '/etc/profile' ] && source /etc/profile || { [ -f '/var/jb/etc/profile' ] && source /var/jb/etc/profile || echo 'Where the fuck `profile`?' 1>&2; } && dpkg --print-architecture | tr -d '\n' || echo 'unknown'", xmz::cmd::ShellType::BASH);
    #endif
}

std::string get_jb_path() {
    #if defined(__roothide__)
        return jbroot("/");
    #elif defined(__rootless__)
        return "/var/jb/";
    #else
        std::string arch = get_jbarch();
        if (arch == "iphoneos-arm64") { return "/var/jb/"; } 
        else if (arch == "iphoneos-arm64e") { return jbroot("/"); } 
        else { return "/"; }
    #endif
}

std::string get_a1_path() {
    return get_jb_path() + "a1";
}

@interface A1Executor : NSObject
+ (instancetype)shared;
- (NSString *)executeCommand:(NSString *)cmd;
- (BOOL)executeCommandSync:(NSString *)cmd;
- (BOOL)isA1Running;
- (NSDictionary<NSString *,NSString *> *)currentModeStatus;
- (NSArray<NSString *> *)priorityListForType:(NSString *)type;
- (NSDictionary<NSString *,NSString *> *)customPriorityMap;
- (void)startA1;
- (void)stopA1;
- (void)restartA1;
- (void)returnPriority;
- (void)setMode:(NSString *)mode on:(BOOL)on;
- (void)addPriority:(NSString *)process type:(NSString *)type value:(nullable NSString *)value;
- (void)removePriority:(NSString *)process;
- (void)setPriorityValue:(NSString *)type value:(NSInteger)val;
- (void)cleanType:(NSString *)type;
- (void)saveConfig;
- (void)restoreConfig;
- (void)setAutoApply:(BOOL)enable;
- (void)setCompatMode:(BOOL)enable;
- (void)setLockMode:(BOOL)enable;
- (void)setSudoFor:(NSString *)target on:(BOOL)on;
- (void)setRootMode:(BOOL)enable;
- (void)setOptimizeInterval:(NSInteger)seconds;
- (void)setLoopSleepInterval:(NSInteger)seconds;
- (NSArray<NSString *> *)moduleList;
- (void)moduleEnable:(NSString *)modId enable:(BOOL)enable;
- (void)moduleInstall:(NSString *)filePath;
- (void)modulePack:(NSString *)dirPath;
- (void)moduleRemove:(NSString *)modId;
- (void)loadModules;
- (NSString *)getConfigContent;
@end

@implementation A1Executor { NSString *_a1ctlPath; }
+ (instancetype)shared {
    static A1Executor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        std::string findCmd = ". /etc/profile 2>/dev/null || . /var/jb/etc/profile 2>/dev/null || true; which a1ctl 2>/dev/null || echo ''";
        auto result = xmz::cmd::runbash_capture(findCmd);
        std::string output = result.stdout_output;
        if (!output.empty()) {
            output.erase(std::remove(output.begin(), output.end(), '\n'), output.end());
            if (!output.empty() && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:output.c_str()]]) {
                _a1ctlPath = [NSString stringWithUTF8String:output.c_str()];
            } else {
                _a1ctlPath = @"a1ctl";
            }
        } else {
            _a1ctlPath = @"a1ctl";
        }
    }
    return self;
}
- (NSString *)executeCommand:(NSString *)cmd {
    auto result = xmz::cmd::runbash_capture(std::string([cmd UTF8String]));
    return [NSString stringWithUTF8String:result.stdout_output.c_str()];
}

- (BOOL)executeCommandSync:(NSString *)cmd {
    std::string cmdStr = cmd ? std::string([cmd UTF8String]) : "";
    xmz::log::info("Execute the order: ", cmdStr);
    xmz::log::info("Current user: ", getuid());
    int exitCode = xmz::cmd::runbash(cmdStr);
    BOOL result = (exitCode == 0);
    xmz::log::info("Execution results: ", result ? "success" : "be defeated");
    xmz::log::info("exit code: ", exitCode);
    return result;
}

- (BOOL)isA1Running { return [[self executeCommand:[NSString stringWithFormat:@"%@ status", _a1ctlPath]] containsString:@"✓ A1 正在运行"]; }
- (NSDictionary<NSString *,NSString *> *)currentModeStatus {
    NSString *config = [self executeCommand:[NSString stringWithFormat:@"%@ config", _a1ctlPath]];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (NSString *line in [config componentsSeparatedByString:@"\n"]) {
        if ([line containsString:@"loop="]) dict[@"loop"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"Auto_Adjust="]) dict[@"auto_adjust"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"SCHEDULED_GUARD="]) dict[@"scheduled_guard"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"Experimental="]) dict[@"exp"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"Log_Reincarnation="]) dict[@"olr"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"Custom_Priority_Enabled="]) dict[@"custom"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"Auto_Apply="]) dict[@"auto_apply"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"compat_mode="]) dict[@"compat"] = [line containsString:@"true"] ? @"on" : @"off";
        else if ([line containsString:@"lock_use="]) dict[@"lock"] = [line containsString:@"true"] ? @"on" : @"off";
    }
    return dict;
}

- (NSArray<NSString *> *)priorityListForType:(NSString *)type {
    NSString *output = [self executeCommand:[NSString stringWithFormat:@"%@ list %@", _a1ctlPath, type]];
    NSMutableArray *list = [NSMutableArray array];
    BOOL contentStart = NO;
    for (NSString *line in [output componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"---"] || [line hasPrefix:@"共"]) continue;
        if ([line containsString:@"优先级进程"] || [line containsString:@"优先级列表"]) { contentStart = YES; continue; }
        if (contentStart && line.length > 0 && ![line hasPrefix:@" "]) {
            if ([type isEqualToString:@"custom"]) {
                NSArray *parts = [line componentsSeparatedByString:@"="];
                if (parts.count == 2) [list addObject:parts[0]];
            } else [list addObject:line];
        }
    }
    return list;
}

- (NSDictionary<NSString *,NSString *> *)customPriorityMap {
    NSString *output = [self executeCommand:[NSString stringWithFormat:@"%@ list custom", _a1ctlPath]];
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    BOOL inContent = NO;
    for (NSString *line in [output componentsSeparatedByString:@"\n"]) {
        if ([line containsString:@"自定义优先级列表"]) { inContent = YES; continue; }
        if (inContent && [line containsString:@"="]) {
            NSArray *parts = [line componentsSeparatedByString:@"="];
            if (parts.count == 2) map[parts[0]] = parts[1];
        }
    }
    return map;
}

- (void)startA1 { [self executeCommandSync:[NSString stringWithFormat:@"%@ start", _a1ctlPath]]; }
- (void)stopA1 { [self executeCommandSync:[NSString stringWithFormat:@"%@ stop", _a1ctlPath]]; }
- (void)restartA1 { [self executeCommandSync:[NSString stringWithFormat:@"%@ restart", _a1ctlPath]]; }
- (void)returnPriority { [self executeCommandSync:[NSString stringWithFormat:@"%@ return", _a1ctlPath]]; }
- (void)setMode:(NSString *)mode on:(BOOL)on { [self executeCommandSync:[NSString stringWithFormat:@"%@ %@ %@", _a1ctlPath, mode, on ? @"on" : @"off"]]; }
- (void)addPriority:(NSString *)process type:(NSString *)type value:(NSString *)value {
    if ([type isEqualToString:@"custom"] && value) [self executeCommandSync:[NSString stringWithFormat:@"%@ add %@ %@", _a1ctlPath, process, value]];
    else [self executeCommandSync:[NSString stringWithFormat:@"%@ add %@ %@", _a1ctlPath, type, process]];
}

- (void)removePriority:(NSString *)process { [self executeCommandSync:[NSString stringWithFormat:@"%@ remove %@", _a1ctlPath, process]]; }
- (void)setPriorityValue:(NSString *)type value:(NSInteger)val { [self executeCommandSync:[NSString stringWithFormat:@"%@ set %@ %ld", _a1ctlPath, type, (long)val]]; }
- (void)cleanType:(NSString *)type { [self executeCommandSync:[NSString stringWithFormat:@"%@ clean %@", _a1ctlPath, type]]; }
- (void)saveConfig { [self executeCommandSync:[NSString stringWithFormat:@"%@ save", _a1ctlPath]]; }
- (void)restoreConfig { [self executeCommandSync:[NSString stringWithFormat:@"%@ restore", _a1ctlPath]]; }
- (void)setAutoApply:(BOOL)enable { [self setMode:@"auto-apply" on:enable]; }
- (void)setCompatMode:(BOOL)enable { [self setMode:@"compat" on:enable]; }
- (void)setLockMode:(BOOL)enable { [self setMode:@"lock" on:enable]; }
- (void)setSudoFor:(NSString *)target on:(BOOL)on { [self executeCommandSync:[NSString stringWithFormat:@"%@ sudo %@ %@", _a1ctlPath, on ? @"on" : @"off", target]]; }
- (void)setRootMode:(BOOL)enable { [self executeCommandSync:[NSString stringWithFormat:@"%@ root %@", _a1ctlPath, enable ? @"on" : @"off"]]; }
- (void)setOptimizeInterval:(NSInteger)seconds { [self executeCommandSync:[NSString stringWithFormat:@"%@ set-interval %ld", _a1ctlPath, (long)seconds]]; }
- (void)setLoopSleepInterval:(NSInteger)seconds { [self executeCommandSync:[NSString stringWithFormat:@"%@ loop-sleep %ld", _a1ctlPath, (long)seconds]]; }
- (NSString *)getConfigContent { return [self executeCommand:[NSString stringWithFormat:@"%@ config", _a1ctlPath]]; }
- (NSArray<NSString *> *)moduleList {
    NSMutableArray *modules = [NSMutableArray array];
    for (NSString *line in [[self executeCommand:[NSString stringWithFormat:@"%@ mod list", _a1ctlPath]] componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"  - "]) [modules addObject:[line substringFromIndex:4]];
    }
    return modules;
}

- (void)moduleEnable:(NSString *)modId enable:(BOOL)enable { [self executeCommandSync:[NSString stringWithFormat:@"%@ mod %@ %@", _a1ctlPath, enable ? @"enable" : @"disable", modId]]; }
- (void)moduleInstall:(NSString *)filePath { [self executeCommandSync:[NSString stringWithFormat:@"%@ mod install \"%@\"", _a1ctlPath, filePath]]; }
- (void)modulePack:(NSString *)dirPath { [self executeCommandSync:[NSString stringWithFormat:@"%@ mod pack \"%@\"", _a1ctlPath, dirPath]]; }
- (void)moduleRemove:(NSString *)modId { [self executeCommandSync:[NSString stringWithFormat:@"%@ mod remove %@", _a1ctlPath, modId]]; }
- (void)loadModules { [self executeCommandSync:[NSString stringWithFormat:@"%@ mod load", _a1ctlPath]]; }
@end

#pragma mark - ViewControllers
@interface StatusViewController : UIViewController
@end

@implementation StatusViewController {
    UIImageView *_statusIcon;
    UILabel *_statusLabel;
    UILabel *_statusDescLabel;
    UIStackView *_featuresStack;
    UILabel *_featuresTitle;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"A1 状态";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}
// 确保每次回到此页面都会刷新状态
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshStatus];
}

- (void)setupUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    xmz::ui::layout::fill(scroll, self.view);
    
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
    // 顶部大状态卡片
    UIView *statusCard = [[UIView alloc] init];
    [statusCard applyCardStyle];
    [mainStack addArrangedSubview:statusCard];
    
    UIStackView *statusVStack = [[UIStackView alloc] init];
    statusVStack.axis = UILayoutConstraintAxisVertical;
    statusVStack.spacing = 12;
    statusVStack.alignment = UIStackViewAlignmentCenter;
    statusVStack.translatesAutoresizingMaskIntoConstraints = NO;
    [statusCard addSubview:statusVStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [statusVStack.topAnchor constraintEqualToAnchor:statusCard.topAnchor constant:32],
        [statusVStack.bottomAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:-32],
        [statusVStack.centerXAnchor constraintEqualToAnchor:statusCard.centerXAnchor]
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
    
    [statusVStack addArrangedSubview:_statusIcon];
    [statusVStack addArrangedSubview:_statusLabel];
    [statusVStack addArrangedSubview:_statusDescLabel];
    // 更简洁的已启用模式卡片
    UIView *featuresCard = [[UIView alloc] init];
    [featuresCard applyCardStyle];
    [mainStack addArrangedSubview:featuresCard];
    
    _featuresStack = [[UIStackView alloc] init];
    _featuresStack.axis = UILayoutConstraintAxisVertical;
    _featuresStack.spacing = 16;
    _featuresStack.translatesAutoresizingMaskIntoConstraints = NO;
    [featuresCard addSubview:_featuresStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [_featuresStack.topAnchor constraintEqualToAnchor:featuresCard.topAnchor constant:20],
        [_featuresStack.leadingAnchor constraintEqualToAnchor:featuresCard.leadingAnchor constant:20],
        [_featuresStack.trailingAnchor constraintEqualToAnchor:featuresCard.trailingAnchor constant:-20],
        [_featuresStack.bottomAnchor constraintEqualToAnchor:featuresCard.bottomAnchor constant:-20]
    ]];
    
    _featuresTitle = [[UILabel alloc] init];
    _featuresTitle.text = @"当前运行模式";
    _featuresTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [_featuresStack addArrangedSubview:_featuresTitle];
    // 控制按钮组
    UIStackView *buttonGrid1 = [[UIStackView alloc] init];
    buttonGrid1.axis = UILayoutConstraintAxisHorizontal;
    buttonGrid1.spacing = 16;
    buttonGrid1.distribution = UIStackViewDistributionFillEqually;
    [mainStack addArrangedSubview:buttonGrid1];
    
    UIStackView *buttonGrid2 = [[UIStackView alloc] init];
    buttonGrid2.axis = UILayoutConstraintAxisHorizontal;
    buttonGrid2.spacing = 16;
    buttonGrid2.distribution = UIStackViewDistributionFillEqually;
    [mainStack addArrangedSubview:buttonGrid2];
    
    NSArray *buttons = @[
        @[@"启动引擎", @"startA1", @"systemBlueColor"],
        @[@"停止引擎", @"stopA1", @"systemRedColor"],
        @[@"重启引擎", @"restartA1", @"systemOrangeColor"],
        @[@"恢复优先级", @"returnPriority", @"systemGreenColor"]
    ];
    for (int i=0; i<buttons.count; i++) {
        NSArray *item = buttons[i];
        UIButton *btn = [UIButton modernButtonWithTitle:item[0]];
        btn.backgroundColor = [UIColor performSelector:NSSelectorFromString(item[2])];
        btn.layer.shadowColor = btn.backgroundColor.CGColor;
        [btn addTarget:self action:NSSelectorFromString(item[1]) forControlEvents:UIControlEventTouchUpInside];
        if (i < 2) [buttonGrid1 addArrangedSubview:btn];
        else [buttonGrid2 addArrangedSubview:btn];
    }
}

- (void)refreshStatus {
    BOOL running = [[A1Executor shared] isA1Running];
    // 更新主状态区
    if (running) {
        _statusIcon.image = [UIImage systemImageNamed:@"checkmark.shield.fill"];
        _statusIcon.tintColor = [UIColor systemGreenColor];
        _statusLabel.text = @"A1 正在运行";
        _statusLabel.textColor = [UIColor systemGreenColor];
        _statusDescLabel.text = @"守护引擎已接管系统调度";
    } else {
        _statusIcon.image = [UIImage systemImageNamed:@"xmark.shield.fill"];
        _statusIcon.tintColor = [UIColor systemRedColor];
        _statusLabel.text = @"A1 未运行";
        _statusLabel.textColor = [UIColor systemRedColor];
        _statusDescLabel.text = @"系统处于默认调度状态";
    }
    // 清理旧的模式列表
    for (UIView *sub in _featuresStack.arrangedSubviews) {
        if (sub != _featuresTitle) {
            [sub removeFromSuperview];
        }
    }
    // 更新活跃的运行模式
    NSDictionary *modes = [[A1Executor shared] currentModeStatus];
    NSArray *keys = @[@"loop", @"auto_adjust", @"scheduled_guard", @"exp", @"olr", @"custom", @"auto_apply", @"compat", @"lock"];
    NSArray *names = @[@"循环模式", @"实时自动调整", @"定时守护", @"实验性功能", @"日志轮迴", @"自定义优先级", @"自动生效", @"兼容模式", @"全局锁定"];
    NSArray *icons = @[@"arrow.3.trianglepath", @"bolt.fill", @"clock.fill", @"testtube.2", @"doc.text.fill", @"list.bullet", @"power", @"shield.lefthalf.filled", @"lock.fill"];

    BOOL hasActive = NO;
    for (NSInteger i = 0; i < keys.count; i++) {
        if ([modes[keys[i]] isEqualToString:@"on"]) {
            hasActive = YES;
            UIStackView *row = [[UIStackView alloc] init];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 12;
            
            UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icons[i]]];
            icon.tintColor = [UIColor systemBlueColor];
            [icon.widthAnchor constraintEqualToConstant:22].active = YES;
            [icon.heightAnchor constraintEqualToConstant:22].active = YES;
            icon.contentMode = UIViewContentModeScaleAspectFit;
            
            UILabel *nameLabel = [[UILabel alloc] init];
            nameLabel.text = names[i];
            nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
            
            [row addArrangedSubview:icon];
            [row addArrangedSubview:nameLabel];
            // 弹簧占位符, 靠左对齐
            UIView *spacer = [[UIView alloc] init];
            [row addArrangedSubview:spacer];
            
            [_featuresStack addArrangedSubview:row];
        }
    }

    if (!hasActive) {
        UILabel *emptyLabel = [[UILabel alloc] init];
        emptyLabel.text = @"当前未开启任何附加模式";
        emptyLabel.font = [UIFont systemFontOfSize:14];
        emptyLabel.textColor = [UIColor secondaryLabelColor];
        [_featuresStack addArrangedSubview:emptyLabel];
    }
}

- (void)startA1 { [[A1Executor shared] startA1]; [self refreshStatus]; }
- (void)stopA1 { [[A1Executor shared] stopA1]; [self refreshStatus]; }
- (void)restartA1 { [[A1Executor shared] restartA1]; [self refreshStatus]; }
- (void)returnPriority { [[A1Executor shared] returnPriority]; [self refreshStatus]; }
@end

@interface ModeViewController : UIViewController <UITextFieldDelegate>
@end

@implementation ModeViewController {
    UIScrollView *_scrollView;
    NSMutableDictionary *_switches;
    UITextField *_activeField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"模式控制";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
    [self registerForKeyboardNotifications];
}
// 确保每次重新进入此页面都会加载底层最新配置, 解决开关视觉失效问题
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadCurrentStates];
}

- (void)setupUI {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];
    xmz::ui::layout::fill(_scrollView, self.view);
    
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
    // 模式开关卡片
    NSArray *modes = @[
        @{@"key":@"loop", @"title":@"循环模式", @"desc":@"持续监控并后台调整优先级"},
        @{@"key":@"auto-adjust", @"title":@"实时自动调整", @"desc":@"根据当前设备负载动态优化"},
        @{@"key":@"scheduled-guard", @"title":@"定时守护", @"desc":@"定期深度检查后台进程运行状态"},
        @{@"key":@"exp", @"title":@"实验性功能", @"desc":@"启用未稳定的底层尝鲜新特性"},
        @{@"key":@"olr", @"title":@"日志轮迴", @"desc":@"智能自动管理和清理老旧日志文件"},
        @{@"key":@"custom", @"title":@"自定义优先级", @"desc":@"允许手动介入指定关键进程优先级"},
        @{@"key":@"auto-apply", @"title":@"自动生效", @"desc":@"开机越狱环境加载后自动启用"},
        @{@"key":@"compat", @"title":@"兼容模式", @"desc":@"提高在部分特殊系统环境下的兼容性"},
        @{@"key":@"lock", @"title":@"安全锁定", @"desc":@"锁定当前设置，防止被其他脚本覆盖"}
    ];
    
    _switches = [NSMutableDictionary dictionary];
    for (NSDictionary *mode in modes) {
        [mainStack addArrangedSubview:[self createCardWithTitle:mode[@"title"] description:mode[@"desc"] key:mode[@"key"]]];
    }
    // 补全丢失的功能设定卡片
    // 间隔设置卡片
    [mainStack addArrangedSubview:[self createInputCardWithTitle:@"优化间隔(秒)" placeholder:@"当前值" action:@selector(setInterval:)]];
    // 循环休眠卡片
    [mainStack addArrangedSubview:[self createInputCardWithTitle:@"循环休眠(秒)" placeholder:@"当前值" action:@selector(setLoopSleep:)]];
    // Sudo 免密模式卡片
    UIView *sudoCard = [[UIView alloc] init];
    [sudoCard applyCardStyle];
    UIStackView *sudoStack = [[UIStackView alloc] init];
    sudoStack.axis = UILayoutConstraintAxisVertical;
    sudoStack.spacing = 16;
    sudoStack.translatesAutoresizingMaskIntoConstraints = NO;
    [sudoCard addSubview:sudoStack];
    [NSLayoutConstraint activateConstraints:@[
        [sudoStack.leadingAnchor constraintEqualToAnchor:sudoCard.leadingAnchor constant:20],
        [sudoStack.trailingAnchor constraintEqualToAnchor:sudoCard.trailingAnchor constant:-20],
        [sudoStack.topAnchor constraintEqualToAnchor:sudoCard.topAnchor constant:18],
        [sudoStack.bottomAnchor constraintEqualToAnchor:sudoCard.bottomAnchor constant:-18]
    ]];
    
    UILabel *sudoTitle = [[UILabel alloc] init];
    sudoTitle.text = @"Sudo 免密模式";
    sudoTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    
    UISegmentedControl *sudoSeg = [[UISegmentedControl alloc] initWithItems:@[@"a1", @"a1ctl", @"all"]];
    sudoSeg.selectedSegmentIndex = 0;
    
    UISwitch *sudoSwitch = [[UISwitch alloc] init];
    [sudoSwitch addTarget:self action:@selector(sudoChanged:) forControlEvents:UIControlEventValueChanged];
    objc_setAssociatedObject(sudoSwitch, "seg", sudoSeg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    UIStackView *sudoRow = [[UIStackView alloc] init];
    sudoRow.axis = UILayoutConstraintAxisHorizontal;
    sudoRow.spacing = 12;
    [sudoRow addArrangedSubview:sudoTitle];
    [sudoRow addArrangedSubview:sudoSeg];
    [sudoRow addArrangedSubview:sudoSwitch];
    [sudoStack addArrangedSubview:sudoRow];
    [mainStack addArrangedSubview:sudoCard];
    // 免Root执行卡片
    UIView *rootCard = [[UIView alloc] init];
    [rootCard applyCardStyle];
    UIStackView *rootRow = [[UIStackView alloc] init];
    rootRow.axis = UILayoutConstraintAxisHorizontal;
    rootRow.alignment = UIStackViewAlignmentCenter;
    rootRow.translatesAutoresizingMaskIntoConstraints = NO;
    [rootCard addSubview:rootRow];
    [NSLayoutConstraint activateConstraints:@[
        [rootRow.leadingAnchor constraintEqualToAnchor:rootCard.leadingAnchor constant:20],
        [rootRow.trailingAnchor constraintEqualToAnchor:rootCard.trailingAnchor constant:-20],
        [rootRow.topAnchor constraintEqualToAnchor:rootCard.topAnchor constant:18],
        [rootRow.bottomAnchor constraintEqualToAnchor:rootCard.bottomAnchor constant:-18]
    ]];
    
    UILabel *rootTitle = [[UILabel alloc] init];
    rootTitle.text = @"免Root执行a1ctl";
    rootTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    
    UISwitch *rootSwitch = [[UISwitch alloc] init];
    [rootSwitch addTarget:self action:@selector(rootChanged:) forControlEvents:UIControlEventValueChanged];
    _switches[@"root"] = rootSwitch;
    
    [rootRow addArrangedSubview:rootTitle];
    [rootRow addArrangedSubview:rootSwitch];
    [mainStack addArrangedSubview:rootCard];
}

- (UIView *)createCardWithTitle:(NSString *)title description:(NSString *)desc key:(NSString *)key {
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

- (UIView *)createInputCardWithTitle:(NSString *)title placeholder:(NSString *)ph action:(SEL)action {
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
    
    UITextField *field = [[UITextField alloc] init];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = ph;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.delegate = self;
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:@"设置" forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemBlueColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 8;
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [btn.widthAnchor constraintEqualToConstant:60].active = YES;
    [btn.heightAnchor constraintEqualToConstant:34].active = YES;
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(btn, "field", field, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [hStack addArrangedSubview:titleLabel];
    [hStack addArrangedSubview:field];
    [hStack addArrangedSubview:btn];
    
    return card;
}

- (void)loadCurrentStates {
    NSDictionary *modes = [[A1Executor shared] currentModeStatus];
    for (NSString *key in modes) {
        if (_switches[key]) {
            UISwitch *switchControl = (UISwitch *)_switches[key];
            switchControl.on = [modes[key] isEqualToString:@"on"];
        }
    }
}

- (void)switchChanged:(UISwitch *)sender {
    for (NSString *k in _switches) {
        if ([_switches[k] isEqual:sender]) {
            [[A1Executor shared] setMode:k on:sender.on]; break;
        }
    }
}
// 功能回调
- (void)setInterval:(UIButton *)sender {
    UITextField *field = objc_getAssociatedObject(sender, "field");
    NSInteger val = [field.text integerValue];
    if (val > 0) [[A1Executor shared] setOptimizeInterval:val];
    field.text = @"";
    [field resignFirstResponder];
}

- (void)setLoopSleep:(UIButton *)sender {
    UITextField *field = objc_getAssociatedObject(sender, "field");
    NSInteger val = [field.text integerValue];
    if (val > 0) [[A1Executor shared] setLoopSleepInterval:val];
    field.text = @"";
    [field resignFirstResponder];
}

- (void)sudoChanged:(UISwitch *)sender {
    UISegmentedControl *seg = objc_getAssociatedObject(sender, "seg");
    NSArray *targets = @[@"a1", @"a1ctl", @"all"];
    NSString *target = targets[seg.selectedSegmentIndex];
    [[A1Executor shared] setSudoFor:target on:sender.on];
}

- (void)rootChanged:(UISwitch *)sender { [[A1Executor shared] setRootMode:sender.on]; }
// 键盘处理
- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height + 20, 0.0);
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    _scrollView.contentInset = UIEdgeInsetsZero;
    _scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField { _activeField = textField; }
- (void)textFieldDidEndEditing:(UITextField *)textField { _activeField = nil; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end


@interface PriorityViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@end

@implementation PriorityViewController {
    UISegmentedControl *_segmented;
    UITableView *_tableView;
    NSArray<NSString *> *_dataSource;
    NSDictionary<NSString *,NSString *> *_customMap;
    NSString *_currentType;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"进程优先级";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadData];
}

- (void)setupUI {
    _segmented = [[UISegmentedControl alloc] initWithItems:@[@"高优先", @"低优先", @"自定义"]];
    _segmented.selectedSegmentIndex = 0;
    _currentType = @"high";
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
    _currentType = @[@"high", @"low", @"custom"][_segmented.selectedSegmentIndex];
    [self loadData];
}

- (void)loadData {
    if ([_currentType isEqualToString:@"custom"]) {
        _customMap = [[A1Executor shared] customPriorityMap];
        _dataSource = _customMap.allKeys;
    } else {
        _dataSource = [[A1Executor shared] priorityListForType:_currentType];
    }
    [_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _dataSource.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    NSString *proc = _dataSource[indexPath.row];
    cell.textLabel.text = [_currentType isEqualToString:@"custom"] ? [NSString stringWithFormat:@"%@ = %@", proc, _customMap[proc]] : proc;
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

- (void)addItem {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"配置进程" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"输入进程名"; }];
    if ([_currentType isEqualToString:@"custom"]) [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"优先级 (0-99)"; tf.keyboardType = UIKeyboardTypeNumberPad; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        if (alert.textFields.firstObject.text.length > 0) {
            [[A1Executor shared] addPriority:alert.textFields.firstObject.text type:_currentType value:alert.textFields.count > 1 ? alert.textFields[1].text : nil];
            [self loadData];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@interface ConfigViewController : UIViewController
@end

@implementation ConfigViewController { UITextView *_configTextView; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"内核维护";
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
    xmz::ui::layout::fill(scroll, self.view);
    
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
        @[@"保存当前配置", @"saveConfig", @"systemBlueColor"],
        @[@"重置出厂配置", @"restoreConfig", @"systemOrangeColor"],
        @[@"清理缓存 (TMP)", @"cleanTmp", @"systemRedColor"],
        @[@"清理 APT 缓存", @"cleanApt", @"systemRedColor"],
        @[@"清空运行日志", @"cleanLogs", @"systemRedColor"]
    ];
    for (NSArray *item in buttons) {
        UIButton *btn = [UIButton modernButtonWithTitle:item[0]];
        btn.backgroundColor = [UIColor performSelector:NSSelectorFromString(item[2])];
        btn.layer.shadowColor = btn.backgroundColor.CGColor;
        [btn addTarget:self action:NSSelectorFromString(item[1]) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:btn];
    }
    
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
- (void)refreshConfig { _configTextView.text = [[A1Executor shared] getConfigContent]; }
- (void)saveConfig { [[A1Executor shared] saveConfig]; }
- (void)restoreConfig { [[A1Executor shared] restoreConfig]; [self refreshConfig]; }
- (void)cleanTmp { [[A1Executor shared] cleanType:@"tmp"]; }
- (void)cleanApt { [[A1Executor shared] cleanType:@"apt"]; }
- (void)cleanLogs { [[A1Executor shared] cleanType:@"logs"]; }
@end

@interface ModuleViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>
@end

@implementation ModuleViewController {
    UITableView *_tableView;
    NSArray<NSString *> *_modules;
    UIRefreshControl *_refreshControl;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"模块引擎";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    [self setupUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadModules];
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
    label.text = @"启用模块引擎";
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    UISwitch *gs = [[UISwitch alloc] init];
    [gs addTarget:self action:@selector(globalSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [topStack addArrangedSubview:label];
    [topStack addArrangedSubview:gs];
    
    UIStackView *btnStack = [[UIStackView alloc] init];
    btnStack.axis = UILayoutConstraintAxisHorizontal;
    btnStack.spacing = 16;
    btnStack.distribution = UIStackViewDistributionFillEqually;
    btnStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:btnStack];
    
    UIButton *btnInstall = [UIButton modernButtonWithTitle:@"导入"];
    [btnInstall addTarget:self action:@selector(installModule) forControlEvents:UIControlEventTouchUpInside];
    UIButton *btnLoad = [UIButton modernButtonWithTitle:@"加载"];
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
        [topStack.leadingAnchor constraintEqualToAnchor:topCard.leadingAnchor constant:20],
        [topStack.trailingAnchor constraintEqualToAnchor:topCard.trailingAnchor constant:-20],
        [topStack.topAnchor constraintEqualToAnchor:topCard.topAnchor constant:16],
        [topStack.bottomAnchor constraintEqualToAnchor:topCard.bottomAnchor constant:-16],
        [btnStack.topAnchor constraintEqualToAnchor:topCard.bottomAnchor constant:20],
        [btnStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [btnStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_tableView.topAnchor constraintEqualToAnchor:btnStack.bottomAnchor constant:16],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}
- (void)globalSwitchChanged:(UISwitch *)sender { [[A1Executor shared] executeCommandSync:[NSString stringWithFormat:@"a1ctl mod %@", sender.on ? @"on" : @"off"]]; }
- (void)loadModules { _modules = [[A1Executor shared] moduleList]; [_tableView reloadData]; [_refreshControl endRefreshing]; }
- (void)installModule {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeOpen];
#pragma clang diagnostic pop
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [[A1Executor shared] moduleInstall:urls.firstObject.path];
    [self loadModules];
}

- (void)loadModulesAction { [[A1Executor shared] loadModules]; }
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

#pragma mark - MainTabBarController & Setup
@interface MainTabBarController : UITabBarController
@property (nonatomic, assign) BOOL hasShownTestAlert;
@end

@implementation MainTabBarController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
    [navAppearance configureWithTransparentBackground];
    navAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    navAppearance.titleTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightBold]};
    [UINavigationBar appearance].standardAppearance = navAppearance;
    [UINavigationBar appearance].scrollEdgeAppearance = navAppearance;
    
    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    [tabAppearance configureWithTransparentBackground];
    tabAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    [UITabBar appearance].standardAppearance = tabAppearance;
    if (@available(iOS 15.0, *)) { [UITabBar appearance].scrollEdgeAppearance = tabAppearance; }
    
    UIViewController *v1 = [[UINavigationController alloc] initWithRootViewController:[[StatusViewController alloc] init]];
    v1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"状态" image:[UIImage systemImageNamed:@"gauge"] tag:0];
    
    UIViewController *v2 = [[UINavigationController alloc] initWithRootViewController:[[ModeViewController alloc] init]];
    v2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"模式" image:[UIImage systemImageNamed:@"switch.2"] tag:1];
    
    UIViewController *v3 = [[UINavigationController alloc] initWithRootViewController:[[PriorityViewController alloc] init]];
    v3.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"策略" image:[UIImage systemImageNamed:@"bolt.shield.fill"] tag:2];
    
    UIViewController *v4 = [[UINavigationController alloc] initWithRootViewController:[[ConfigViewController alloc] init]];
    v4.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"维护" image:[UIImage systemImageNamed:@"hammer.fill"] tag:3];
    
    UIViewController *v5 = [[UINavigationController alloc] initWithRootViewController:[[ModuleViewController alloc] init]];
    v5.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"模块" image:[UIImage systemImageNamed:@"puzzlepiece.extension.fill"] tag:4];

    UIViewController *v6 = [[UINavigationController alloc] initWithRootViewController:[[SponsorViewController alloc] init]];
    v6.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"赞助" image:[UIImage systemImageNamed:@"heart.fill"] tag:5];

    self.viewControllers = @[v1, v2, v3, v4, v5, v6];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.hasShownTestAlert) {
        self.hasShownTestAlert = YES;
        NSString *message = [NSString stringWithFormat:@"越狱环境: %s\n引擎路径: %s", get_jbarch().c_str(), get_a1_path().c_str()];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"A1 Control Engine" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (setuid(0) != 0) {
        xmz::log::err("setuid(0) failed");
				xmz::log::err("starting a1gui requires setting UID permissions!");
        return 1;
    }
    std::string a1_path = get_a1_path();
    std::string a1_bak_path = a1_path + "/backup";
    xmz::fs::mkdir(a1_path.c_str());
		if (xmz::aux::is_dir(a1_path.c_str()) == 0) {
				xmz::log::warn("mkdir a1 path (a1_path) failed");
		} else {
				xmz::log::info("mkdir a1 path (a1_path) success or already exists");
		}
    xmz::fs::mkdir(a1_bak_path.c_str());
    if (xmz::aux::is_dir(a1_bak_path.c_str()) == 0) {
				xmz::log::warn("mkdir a1 bak path (a1_bak_path) failed");
		} else {
				xmz::log::info("mkdir a1 bak path (a1_bak_path) success or already exists");
		}
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[MainTabBarController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
				const char *existingPath = getenv("PATH");
				std::string newPath = "/bin:/usr/bin:/usr/local/bin:/var/jb/bin:/var/jb/usr/bin:/var/jb/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:/var/jb/sbin:/var/jb/usr/sbin:/var/jb/usr/local/sbin:/rootfs/usr/bin:/rootfs/bin:/rootfs/sbin:/rootfs/usr/sbin:/rootfs/usr/local/bin:/rootfs/usr/local/sbin";
        if (existingPath != nullptr) {
						newPath += ":";
						newPath += existingPath;
				}
				setenv("PATH", newPath.c_str(), 1);

				if (setuid(0) != 0 && getuid() != 0) {
						xmz::log::error("starting a1gui requires setting UID permissions!");
						xmz::log::error("a1 must be started as root!");
						return 1;
				} else {
				      xmz::log::info("a1gui has started!");
						return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
				}
		}
}

