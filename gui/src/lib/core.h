/*
 * core.h
 * Created by XMZ <ad-ios334@outlook.com> on 10/3/26
 * Copyright (c) 2025-2026 XMZ <ad-ios334@outlook.com> All rights reserved.
 */

#ifndef A1_GUI_CORE_H
#define A1_GUI_CORE_H
#include <libxmz/runsh.hpp>
#pragma mark - Core Engine functions
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

@implementation A1Executor {
    NSString *_a1ctlPath;
}
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
    return xmz::cmd::runbash(std::string([cmd UTF8String])) == 0;
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
#endif // A1_GUI_CORE_H
