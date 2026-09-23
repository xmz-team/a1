// A1Constants.h
#ifndef A1_CONSTANTS_H
#define A1_CONSTANTS_H

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, A1ModeKey) {
    A1ModeLoop,
    A1ModeAutoAdjust,
    A1ModeScheduledGuard,
    A1ModeCustomPriority,
    A1ModeAutoApply,
    A1ModeCompat,
    A1ModeLock,
    A1ModeModule
};

typedef NS_ENUM(NSInteger, A1PriorityType) {
    A1PriorityHigh,
    A1PriorityLow,
    A1PriorityCustom
};

extern NSString * const kA1ModeKeys[];
extern NSString * const kA1ModeDisplayNames[];
extern NSString * const kA1ModeDescriptions[];
extern NSString * const kA1ModeIcons[];

extern NSString * const kA1PriorityTypeNames[];
extern NSString * const kA1PriorityTypeCommands[];

#endif
