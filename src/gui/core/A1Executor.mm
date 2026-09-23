// A1Executor.mm

#import "A1Executor.h"
#import "A1Constants.h"
#import "cfg.h"
#import "env.h"

#include <a1/core/a1core.hpp>
#include <a1/core/a1ctlcore.hpp>
#include <a1/core/a1modcore.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/runsh.hpp>

@implementation A1Executor
auto& _env = g_env;
+ (instancetype)shared {
    static A1Executor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        a1ctl::init_config();
        a1ctl::check_config_conflict();
        a1mod::config modCfg;
        a1mod::init_system(modCfg, g_jb);
    }
    return self;
}

#pragma mark - Internal tools
- (BOOL)runA1ctl:(NSArray<NSString *> *)args {
    NSMutableString *cmd = [NSMutableString stringWithString:@"a1ctl"];
    for (NSString *a in args) [cmd appendFormat:@" %@", a];
    int ret = xmz::cmd::runsh([cmd UTF8String]);
    if (ret != 0) xmz::log::error("a1ctl command failed, ret =", ret);
    return ret == 0;
}

- (BOOL)runA1mod:(NSArray<NSString *> *)args {
    NSMutableString *cmd = [NSMutableString stringWithString:@"a1mod"];
    for (NSString *a in args) [cmd appendFormat:@" %@", a];
    int ret = xmz::cmd::runsh([cmd UTF8String]);
    if (ret != 0) xmz::log::error("a1mod command failed, ret =", ret);
    return ret == 0;
}

- (std::string)configPath { return g_jb.a1config + "/config.ini"; }

#pragma mark - Status inquiry
- (bool)isA1Running { if (a1ctl::check_a1_running() == 1) { return false; } else { return true; } }

- (NSDictionary<NSString *, NSString *> *)currentModeStatus {
    a1::ini::ini_parser parser;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (parser.parse_file([self configPath])) {
        for (int i = 0; i < 9; i++) {
            NSString *key = kA1ModeKeys[i];
            bool value = parser.get_bool("", [key UTF8String], false);
            dict[key] = value ? @"on" : @"off";
        }
    }
    return [dict copy];
}

- (NSString *)getConfigContent {
    std::string path = [self configPath];
    if (xmz::aux::is_file(xmz::aux::parselink(path)) == 0) {
        std::string content = xmz::fs::readfile_str(path);
        return [NSString stringWithUTF8String:content.c_str()];
    }
    return @"# The configuration file was not found";
}

#pragma mark - Service control
- (void)startA1 { [self runA1ctl:@[@"start"]]; }
- (void)stopA1 { [self runA1ctl:@[@"stop"]]; }
- (void)restartA1 { [self runA1ctl:@[@"restart"]]; }

- (void)returnPriority {
    [self runA1ctl:@[@"loop", @"off"]];
    [self runA1ctl:@[@"auto-adjust", @"off"]];
    [self runA1ctl:@[@"scheduled-guard", @"off"]];
    [self runA1ctl:@[@"stop"]];
}

#pragma mark - Pattern control
- (void)setMode:(A1ModeKey)mode on:(BOOL)on from:(nullable id)sender {
    NSString *key = kA1ModeKeys[mode];
    NSString *onoff = on ? @"on" : @"off";
    NSDictionary<NSString *, NSArray<NSString *> *> *cmdMap = @{
        @"loop":              @[@"loop", onoff],
        @"auto_adjust":       @[@"auto-adjust", onoff],
        @"scheduled_guard":   @[@"scheduled-guard", onoff],
        @"custom":            @[@"custom", onoff],
        @"auto_apply":        @[@"auto-apply", onoff],
        @"compat":            @[@"compat", onoff],
        @"lock":              @[@"lock", onoff],
        @"module_switch":     @[@"mod-switch", onoff],
    };
    NSArray<NSString *> *args = cmdMap[key];
    if (args) {
        [self runA1ctl:args];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"A1ModeStatusChangedNotification" object:sender userInfo:@{@"key": key, @"on": @(on)}];
    }
}

- (void)setMode:(A1ModeKey)mode on:(BOOL)on { [self setMode:mode on:on from:nil]; }

#pragma mark - Priority management
- (NSArray<NSString *> *)priorityListForType:(A1PriorityType)type {
    a1::priority_manager pm;
    pm.read_priority_lists();
    
    NSMutableArray *list = [NSMutableArray array];
    const std::vector<std::string>* vec = nullptr;
    switch (type) {
        case A1PriorityHigh: vec = &pm.get_high_list(); break;
        case A1PriorityLow:  vec = &pm.get_low_list();  break;
        default: return @[];
    }
    for (const auto& item : *vec) [list addObject:[NSString stringWithUTF8String:item.c_str()]];
    return [list copy];
}

- (NSDictionary<NSString *, NSString *> *)customPriorityMap {
    a1::priority_manager pm;
    pm.read_priority_lists();
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (const auto& [key, value] : pm.get_custom_list()) dict[[NSString stringWithUTF8String:key.c_str()]] = [NSString stringWithFormat:@"%d", value];
    return [dict copy];
}

- (void)addPriority:(NSString *)process type:(A1PriorityType)type value:(NSString *)value {
    if (type == A1PriorityHigh) [self runA1ctl:@[@"add", @"high", process]];
    else if (type == A1PriorityLow) [self runA1ctl:@[@"add", @"low", process]];
    else if (type == A1PriorityCustom) [self runA1ctl:@[@"add", process, value ?: @"20"]];
}

- (void)removePriority:(NSString *)process { [self runA1ctl:@[@"remove", process]]; }

- (void)clearPriorityList:(A1PriorityType)type {
    NSString *cmd = kA1PriorityTypeCommands[type];
    [self runA1ctl:@[@"clear", cmd]];
}

#pragma mark - Configuration management
- (void)saveConfig {
    std::string configPath = g_jb.a1config + "/config.ini";
    a1::ini::ini_parser parser;
    if (parser.parse_file(configPath)) {
        parser.save_cover(configPath);
        xmz::log::info("Configuration saved");
    }
}

- (void)restoreConfig { [self runA1ctl:@[@"restore"]]; }

#pragma mark - Advanced settings
- (void)setAutoApply:(BOOL)enable { [self runA1ctl:@[@"auto-apply", enable ? @"on" : @"off"]]; }
- (void)setCompatMode:(BOOL)enable { [self runA1ctl:@[@"compat", enable ? @"on" : @"off"]]; }
- (void)setLockMode:(BOOL)enable { [self runA1ctl:@[@"lock", enable ? @"on" : @"off"]]; }
- (void)setOptimizeInterval:(NSInteger)seconds { [self runA1ctl:@[@"set-interval", [NSString stringWithFormat:@"%ld", (long)seconds]]]; }
- (void)setLoopSleepInterval:(NSInteger)seconds { [self runA1ctl:@[@"loop-sleep", [NSString stringWithFormat:@"%ld", (long)seconds]]]; }

- (void)setPriorityValue:(A1PriorityType)type value:(NSInteger)val {
    NSString *cmd = kA1PriorityTypeCommands[type];
    if ([cmd isEqualToString:@"custom"]) cmd = @"high";
    [self runA1ctl:@[@"set", cmd, [NSString stringWithFormat:@"%ld", (long)val]]];
}

#pragma mark - Module management
- (NSArray<NSString *> *)moduleList {
    a1mod::load_db_from_file();
    NSMutableArray *modules = [NSMutableArray array];
    for (const auto& [name, entry] : a1mod::g_module_db.modules) [modules addObject:[NSString stringWithUTF8String:name.c_str()]];
    return [modules copy];
}

- (void)moduleEnable:(NSString *)modId enable:(BOOL)enable { [self runA1mod:@[enable ? @"enable" : @"disable", modId]]; }
- (void)moduleInstall:(NSString *)filePath { [self runA1mod:@[@"install", filePath]]; }
- (void)moduleRemove:(NSString *)modId { [self runA1mod:@[@"remove", modId]]; }
- (void)loadModules {
    [self runA1mod:@[@"list"]];
    a1mod::load_db_from_file();
}
@end
