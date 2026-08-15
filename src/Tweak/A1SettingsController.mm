#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <signal.h>


// 工具函数：读取某文件的全部行（去空行）
NSArray<NSString *> *readLinesFromFile(NSString *path) {
    NSString *content = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding error:nil];
    if (!content) return @[];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length > 0) [lines addObject:t];
    }
    return lines;
}

// 工具函数：从 config.conf 读取某个 key 的值（去除引号和空格）
NSString *readConfigValue(NSString *key) {
    NSArray *lines = readLinesFromFile(CONFIG_FILE);
    NSString *prefix = [NSString stringWithFormat:@"export %@=", key];
    for (NSString *line in lines) {
        if ([line hasPrefix:prefix]) {
            NSString *val = [line substringFromIndex:prefix.length];
            val = [val stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            val = [val stringByReplacingOccurrencesOfString:@"\"" withString:@""];
            return val;
        }
    }
    return nil;
}

// 工具函数：写 config.conf，更新或追加 key=value
BOOL writeConfigValue(NSString *key, NSString *value) {
    NSMutableArray *lines = [NSMutableArray arrayWithArray:readLinesFromFile(CONFIG_FILE)];
    NSString *prefix = [NSString stringWithFormat:@"export %@=", key];
    BOOL found = NO;
    for (int i = 0; i < lines.count; i++) {
        if ([lines[i] hasPrefix:prefix]) {
            lines[i] = [NSString stringWithFormat:@"export %@=%@", key, value];
            found = YES;
            break;
        }
    }
    if (!found) {
        [lines addObject:[NSString stringWithFormat:@"export %@=%@", key, value]];
    }
    NSString *content = [lines componentsJoinedByString:@"\n"];
    return [content writeToFile:CONFIG_FILE atomically:YES
                        encoding:NSUTF8StringEncoding error:nil];
}

// 获取 A1 进程 PID（通过 ps + grep）
pid_t getA1PID(void) {
    FILE *fp = popen("/bin/ps aux | /var/jb/usr/bin/grep -v grep | /var/jb/usr/bin/grep -v a1ctl | /var/jb/usr/bin/grep -E '(a1$|/var/jb/usr/local/bin/a1)' | /var/jb/usr/bin/awk '{print $2}'", "r");
    if (!fp) return -1;
    char buf[16];
    if (fgets(buf, sizeof(buf), fp) != NULL) {
        int pid = atoi(buf);
        pclose(fp);
        return pid;
    }
    pclose(fp);
    return -1;
}

// ----------------------------------------------------------------
// 主控制器
@interface A1SettingsController : PSListController
@end

@implementation A1SettingsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"root" target:self];
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers]; // 刷新状态
}

// ========== 状态显示 ==========
- (NSString *)a1Status {
    pid_t pid = getA1PID();
    return (pid > 0) ? @"运行中" : @"已停止";
}

// ========== 启动/停止 ==========
- (void)startA1 {
    if (getA1PID() > 0) {
        [self showMessage:@"A1 已在运行"];
        return;
    }
    const char *args[] = {"/var/jb/usr/local/bin/a1", NULL};
    pid_t pid;
    posix_spawn(&pid, "/var/jb/usr/local/bin/a1", NULL, NULL, (char *const *)args, NULL);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self reloadSpecifiers];
    });
}

- (void)stopA1 {
    pid_t pid = getA1PID();
    if (pid > 0) {
        kill(pid, SIGTERM);
        sleep(1);
        kill(pid, SIGKILL);
        [self showMessage:@"A1 已停止"];
        [self reloadSpecifiers];
    } else {
        [self showMessage:@"A1 未运行"];
    }
}

// ========== 模式选择 ==========
- (NSString *)getA1Mode {
    if ([readConfigValue(@"loop") boolValue]) return @"loop";
    if ([readConfigValue(@"Auto_Adjust") boolValue]) return @"auto_adjust";
    if ([readConfigValue(@"SCHEDULED_GUARD") boolValue]) return @"scheduled_guard";
    return @"off";
}

- (void)setA1Mode:(NSString *)mode {
    writeConfigValue(@"loop", ([mode isEqualToString:@"loop"] ? @"true" : @"false"));
    writeConfigValue(@"Auto_Adjust", ([mode isEqualToString:@"auto_adjust"] ? @"true" : @"false"));
    writeConfigValue(@"SCHEDULED_GUARD", ([mode isEqualToString:@"scheduled_guard"] ? @"true" : @"false"));
    [self reloadA1IfNeeded];
}

// ========== 开关类（通用模板） ==========
- (NSNumber *)getExperimental {
    return @([readConfigValue(@"Experimental") boolValue]);
}
- (void)setExperimental:(NSNumber *)val {
    writeConfigValue(@"Experimental", val.boolValue ? @"true" : @"false");
    [self reloadA1IfNeeded];
}

- (NSNumber *)getLog_Reincarnation {
    return @([readConfigValue(@"Log_Reincarnation") boolValue]);
}
- (void)setLog_Reincarnation:(NSNumber *)val {
    writeConfigValue(@"Log_Reincarnation", val.boolValue ? @"true" : @"false");
    // 日志轮迴还需要维护 sudoers，此处略
    [self reloadA1IfNeeded];
}

- (NSNumber *)getAuto_Apply {
    return @([readConfigValue(@"Auto_Apply") boolValue]);
}
- (void)setAuto_Apply:(NSNumber *)val {
    writeConfigValue(@"Auto_Apply", val.boolValue ? @"true" : @"false");
    [self reloadA1IfNeeded];
}

- (NSNumber *)getCompat_mode {
    return @([readConfigValue(@"compat_mode") boolValue]);
}
- (void)setCompat_mode:(NSNumber *)val {
    writeConfigValue(@"compat_mode", val.boolValue ? @"true" : @"false");
    [self reloadA1IfNeeded];
}

- (NSNumber *)getCustom_Priority_Enabled {
    return @([readConfigValue(@"Custom_Priority_Enabled") boolValue]);
}
- (void)setCustom_Priority_Enabled:(NSNumber *)val {
    writeConfigValue(@"Custom_Priority_Enabled", val.boolValue ? @"true" : @"false");
    [self reloadA1IfNeeded];
}

- (NSNumber *)getA1_module_switch {
    return @([readConfigValue(@"a1_module_switch") boolValue]);
}
- (void)setA1_module_switch:(NSNumber *)val {
    writeConfigValue(@"a1_module_switch", val.boolValue ? @"true" : @"false");
    [self reloadA1IfNeeded];
}

// ========== 滑块数值 ==========
- (NSNumber *)getHigh_Priority {
    return @([readConfigValue(@"High_Priority") intValue]);
}
- (void)setHigh_Priority:(NSNumber *)val {
    writeConfigValue(@"High_Priority", [val stringValue]);
    [self reloadA1IfNeeded];
}

- (NSNumber *)getLow_Priority {
    return @([readConfigValue(@"Low_Priority") intValue]);
}
- (void)setLow_Priority:(NSNumber *)val {
    writeConfigValue(@"Low_Priority", [val stringValue]);
    [self reloadA1IfNeeded];
}

- (NSNumber *)getLaunchd_Priority {
    return @([readConfigValue(@"Launchd_Priority") intValue]);
}
- (void)setLaunchd_Priority:(NSNumber *)val {
    writeConfigValue(@"Launchd_Priority", [val stringValue]);
    [self reloadA1IfNeeded];
}

// ========== 按钮：保存 / 恢复 / 清理 ==========
- (void)saveConfig {
    [[NSFileManager defaultManager] createDirectoryAtPath:BACKUP_DIR
                              withIntermediateDirectories:YES attributes:nil error:nil];
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *ts = [f stringFromDate:[NSDate date]];
    NSString *dest = [BACKUP_DIR stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"config_backup_%@", ts]];
    [[NSFileManager defaultManager] createDirectoryAtPath:dest
                              withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray *files = @[@"config.conf", @"high_priority.list", @"low_priority.list", @"custom_priority.list"];
    for (NSString *file in files) {
        NSString *src = [CONFIG_DIR stringByAppendingPathComponent:file];
        NSString *dst = [dest stringByAppendingPathComponent:file];
        if ([[NSFileManager defaultManager] fileExistsAtPath:src]) {
            [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil];
        }
    }
    [self showMessage:[NSString stringWithFormat:@"配置已备份至 %@", dest]];
}

- (void)restoreConfig {
    // 可在此实现列表选择恢复，此处简化为恢复最新备份
    NSArray *backups = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:BACKUP_DIR error:nil];
    NSArray *sorted = [backups sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [b compare:a];
    }];
    if (sorted.count == 0) {
        [self showMessage:@"没有可用的备份"];
        return;
    }
    NSString *latest = [BACKUP_DIR stringByAppendingPathComponent:sorted[0]];
    // 复制文件回去
    NSArray *files = @[@"config.conf", @"high_priority.list", @"low_priority.list", @"custom_priority.list"];
    for (NSString *file in files) {
        NSString *src = [latest stringByAppendingPathComponent:file];
        NSString *dst = [CONFIG_DIR stringByAppendingPathComponent:file];
        if ([[NSFileManager defaultManager] fileExistsAtPath:src]) {
            [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
            [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil];
        }
    }
    [self showMessage:@"配置已恢复"];
    [self reloadSpecifiers];
    [self reloadA1IfNeeded];
}

- (void)cleanTmp {
    system("rm -rf /tmp/*");
    [self showMessage:@"临时文件已清理"];
}

- (void)cleanApt {
    system("rm -rf /var/jb/var/lib/apt/lists/* /var/jb/var/cache/apt/archives/*.deb");
    [self showMessage:@"APT 缓存已清理"];
}

- (void)cleanLogs {
    system("find /var/log -type f -name '*.log' -exec sh -c '> {}' \\;");
    system("find /var/jb/var/log -type f -name '*.log' -exec sh -c '> {}' \\;");
    [self showMessage:@"日志已清空"];
}

- (void)reloadA1IfNeeded {
    if ([readConfigValue(@"Auto_Apply") boolValue]) {
        [self stopA1];
        [self startA1];
    }
}

- (void)showMessage:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"A1 设置"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// ----------------------------------------------------------------
// 子页面控制器：高优先级进程列表
@interface HighPriorityListController : PSListController
@end

@implementation HighPriorityListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"HighPriorityList" target:self];
    }
    return _specifiers;
}

- (NSString *)getHighList {
    return [[readLinesFromFile(HIGH_LIST_FILE) componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
}

- (void)setHighList:(NSString *)text {
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *line in lines) {
        NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length > 0) [result addObject:t];
    }
    [result writeToFile:HIGH_LIST_FILE atomically:YES];
}
@end

// 低优先级进程列表
@interface LowPriorityListController : PSListController
@end

@implementation LowPriorityListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"LowPriorityList" target:self];
    }
    return _specifiers;
}

- (NSString *)getLowList {
    return [[readLinesFromFile(LOW_LIST_FILE) componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
}

- (void)setLowList:(NSString *)text {
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *line in lines) {
        NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length > 0) [result addObject:t];
    }
    [result writeToFile:LOW_LIST_FILE atomically:YES];
}
@end

// 自定义优先级进程列表
@interface CustomPriorityListController : PSListController
@end

@implementation CustomPriorityListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"CustomPriorityList" target:self];
    }
    return _specifiers;
}

- (NSString *)getCustomList {
    return [[readLinesFromFile(CUSTOM_LIST_FILE) componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
}

- (void)setCustomList:(NSString *)text {
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *line in lines) {
        NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length > 0) [result addObject:t];
    }
    [result writeToFile:CUSTOM_LIST_FILE atomically:YES];
}
@end