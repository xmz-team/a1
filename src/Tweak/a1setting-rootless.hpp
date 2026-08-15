

#define CONFIG_DIR @"/var/jb/a1"
#define CONFIG_FILE [CONFIG_DIR stringByAppendingPathComponent:@"/config.conf"]
#define HIGH_LIST_FILE [CONFIG_DIR stringByAppendingPathComponent:@"/high_priority.list"]
#define LOW_LIST_FILE [CONFIG_DIR stringByAppendingPathComponent:@"/low_priority.list"]
#define CUSTOM_LIST_FILE [CONFIG_DIR stringByAppendingPathComponent:@"/custom_priority.list"]
#define BACKUP_DIR [CONFIG_DIR stringByAppendingPathComponent:@"/backup"]
