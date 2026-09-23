// A1Constants.mm
#import "A1Constants.h"
#include "cfg.h"

NSString * const kA1ModeKeys[] = {
    @"loop",
    @"auto_adjust",
    @"scheduled_guard",
    @"custom",
    @"auto_apply",
    @"compat",
    @"lock",
    @"module_switch"
};

NSString * const kA1ModeDisplayNames[] = {
    a1gui::locale("loop_mode"),
    a1gui::locale("auto_adjust_mode"),
    a1gui::locale("scheduled_guard_mode"),
    a1gui::locale("custom_mode"),
    a1gui::locale("auto_apply_mode"),
    a1gui::locale("compat_mode"),
    a1gui::locale("lock_mode"),
    a1gui::locale("module_switch_mode")
};

NSString * const kA1ModeDescriptions[] = {
    a1gui::locale("loop_mode_text"),
    a1gui::locale("auto_adjust_mode_text"),
    a1gui::locale("scheduled_guard_mode_text"),
    a1gui::locale("custom_mode_text"),
    a1gui::locale("auto_apply_mode_text"),
    a1gui::locale("compat_mode_text"),
    a1gui::locale("lock_mode_text"),
    a1gui::locale("module_switch_mode_text")
};

NSString * const kA1ModeIcons[] = {
    @"loop.fill",
    @"auto_adjust.fill",
    @"scheduled_guard.fill",
    @"custom.fill",
    @"auto_apply.fill",
    @"compat.fill",
    @"lock.fill",
    @"module.fill"
};

NSString * const kA1PriorityTypeNames[] = {
    a1gui::locale("high_priority"),
    a1gui::locale("low_priority"),
    a1gui::locale("customization"),
};

NSString * const kA1PriorityTypeCommands[] = {
    @"high",
    @"low",
    @"custom"
};
