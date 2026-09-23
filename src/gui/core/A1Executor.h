// A1Executor.h
#ifndef A1_EXECUTOR_H
#define A1_EXECUTOR_H

#import <Foundation/Foundation.h>
#import "A1Constants.h"

NS_ASSUME_NONNULL_BEGIN
@interface A1Executor : NSObject
+ (instancetype)shared;

- (bool)isA1Running;
- (NSDictionary<NSString *, NSString *> *)currentModeStatus;

- (void)startA1;
- (void)stopA1;
- (void)restartA1;
- (void)returnPriority;

- (void)setMode:(A1ModeKey)mode on:(BOOL)on;
- (void)setMode:(A1ModeKey)mode on:(BOOL)on from:(nullable id)sender;

- (NSArray<NSString *> *)priorityListForType:(A1PriorityType)type;
- (NSDictionary<NSString *, NSString *> *)customPriorityMap;
- (void)addPriority:(NSString *)process type:(A1PriorityType)type value:(nullable NSString *)value;
- (void)removePriority:(NSString *)process;
- (void)clearPriorityList:(A1PriorityType)type;

- (void)saveConfig;
- (void)restoreConfig;
- (NSString *)getConfigContent;

- (void)setAutoApply:(BOOL)enable;
- (void)setCompatMode:(BOOL)enable;
- (void)setLockMode:(BOOL)enable;
- (void)setOptimizeInterval:(NSInteger)seconds;
- (void)setLoopSleepInterval:(NSInteger)seconds;
- (void)setPriorityValue:(A1PriorityType)type value:(NSInteger)val;

- (NSArray<NSString *> *)moduleList;
- (void)moduleEnable:(NSString *)modId enable:(BOOL)enable;
- (void)moduleInstall:(NSString *)filePath;
- (void)moduleRemove:(NSString *)modId;
- (void)loadModules;
@end
NS_ASSUME_NONNULL_END
#endif
