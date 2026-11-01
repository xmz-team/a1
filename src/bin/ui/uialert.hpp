/*
 * uialert.hpp
 * Created by XMZ <xmz-team@outlook.com> on 2026-10-31
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

#pragma once
#include "CF.hpp"
#include <Foundation/Foundation.h>
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

namespace a1::bin::uialert {
namespace _ {
struct result {
    unsigned long button;
    std::vector<std::string> inputs;
    std::string json;
};

inline result run(
    CFOptionFlags flags,
    double timeout,
    int priority,
    const std::string &title,
    const std::string &body,
    const std::string &primary,
    const std::string &secondary,
    const std::string &tertiary,
    const std::vector<std::string> &input_titles,
    const std::vector<bool> &input_secure,
    bool want_json = false
) {
    NSMutableDictionary *alert = [[NSMutableDictionary alloc] init];
    NSMutableArray *inputs     = [[NSMutableArray alloc] init];

    if (!body.empty())      [alert addEntriesFromDictionary:@{(__bridge NSString *)kCFUserNotificationAlertMessageKey:[NSString stringWithUTF8String:body.c_str()]}];
    if (!primary.empty())   [alert addEntriesFromDictionary:@{(__bridge NSString *)kCFUserNotificationDefaultButtonTitleKey:[NSString stringWithUTF8String:primary.c_str()]}];
    if (!secondary.empty()) [alert addEntriesFromDictionary:@{(__bridge NSString *)kCFUserNotificationAlternateButtonTitleKey:[NSString stringWithUTF8String:secondary.c_str()]}];
    if (!tertiary.empty())  [alert addEntriesFromDictionary:@{(__bridge NSString *)kCFUserNotificationOtherButtonTitleKey:[NSString stringWithUTF8String:tertiary.c_str()]}];

    for (size_t i = 0; i < input_titles.size(); ++i) {
        [inputs addObject:[NSString stringWithUTF8String:input_titles[i].c_str()]];
        if (i < input_secure.size() && input_secure[i]) flags |= CFUserNotificationSecureTextField((CFIndex)i);
    }

    flags |= (CFOptionFlags)priority;

    [alert addEntriesFromDictionary:@{(__bridge NSString *)kCFUserNotificationAlertHeaderKey:[NSString stringWithUTF8String:title.c_str()]}];

    if (inputs.count > 0) [alert addEntriesFromDictionary:@{(__bridge NSString *)kCFUserNotificationTextFieldTitlesKey:inputs}];

    CFUserNotificationRef notif = CFUserNotificationCreate(kCFAllocatorDefault,
                                                           timeout, flags, NULL,
                                                           (__bridge CFMutableDictionaryRef)alert);

    CFOptionFlags cfRes;
    CFUserNotificationReceiveResponse(notif, 0, &cfRes);

    NSDictionary *response = (__bridge NSDictionary *)CFUserNotificationGetResponseDictionary(notif);

    result out;
    out.button = cfRes;

    if (cfRes != kCFUserNotificationCancelResponse && inputs.count >= 1) {
        NSObject *input = [response valueForKey:(__bridge NSString *)kCFUserNotificationTextFieldValuesKey];
        if ([input isKindOfClass:NSString.class])     out.inputs.push_back(std::string([(NSString *)input UTF8String]));
        else if ([input isKindOfClass:NSArray.class]) for (NSString *s in (NSArray *)input) out.inputs.push_back(std::string(s.UTF8String));
    }

    if (want_json) {
        NSMutableDictionary *outDict = [[NSMutableDictionary alloc] init];
        [outDict addEntriesFromDictionary:@{@"button": [NSNumber numberWithUnsignedLong:cfRes]}];
        if (!out.inputs.empty()) {
            NSMutableArray *arr = [[NSMutableArray alloc] init];
            for (const auto &s : out.inputs) [arr addObject:[NSString stringWithUTF8String:s.c_str()]];
            [outDict addEntriesFromDictionary:@{@"inputs": arr}];
        }
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:outDict options:0 error:&error];
        if (!error && jsonData) {
            out.json = std::string([[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] UTF8String]);
        }
    }

    CFRelease(notif);
    return out;
}

inline int parse_priority(const std::string &value, const char **errstr) {
    long v = strtol(value.c_str(), NULL, 10);
    if (v < 0 || v > 3) {
        *errstr = value.c_str();
        return kCFUserNotificationNoteAlertLevel;
    }
    switch (v) {
        case 0: return kCFUserNotificationPlainAlertLevel;
        case 1: return kCFUserNotificationNoteAlertLevel;
        case 2: return kCFUserNotificationCautionAlertLevel;
        case 3: return kCFUserNotificationStopAlertLevel;
    }
    return kCFUserNotificationNoteAlertLevel;
}
} /* namespace _ */

inline _::result body(
    const std::string &title,
    const std::string &body_text,
    const std::string &primary = "",
    const std::string &secondary = "",
    const std::string &tertiary = "",
    double timeout = 0,
    int priority = kCFUserNotificationNoteAlertLevel,
    const std::vector<std::string> &input_titles = {},
    const std::vector<bool> &input_secure = {}
) { return _::run(0, timeout, priority, title, body_text, primary, secondary, tertiary, input_titles, input_secure); }

inline _::result primary(
    const std::string &title,
    const std::string &primary_text,
    const std::string &body_text = "",
    const std::string &secondary = "",
    const std::string &tertiary = "",
    double timeout = 0,
    int priority = kCFUserNotificationNoteAlertLevel,
    const std::vector<std::string> &input_titles = {},
    const std::vector<bool> &input_secure = {}
) { return _::run(0, timeout, priority, title, body_text, primary_text, secondary, tertiary, input_titles, input_secure); }

inline _::result secondary(
    const std::string &title,
    const std::string &secondary_text,
    const std::string &body_text = "",
    const std::string &primary = "",
    const std::string &tertiary = "",
    double timeout = 0,
    int priority = kCFUserNotificationNoteAlertLevel,
    const std::vector<std::string> &input_titles = {},
    const std::vector<bool> &input_secure = {}
) { return _::run(0, timeout, priority, title, body_text, primary, secondary_text, tertiary, input_titles, input_secure); }

inline _::result tertiary(
    const std::string &title,
    const std::string &tertiary_text,
    const std::string &body_text = "",
    const std::string &primary = "",
    const std::string &secondary = "",
    double timeout = 0,
    int priority = kCFUserNotificationNoteAlertLevel,
    const std::vector<std::string> &input_titles = {},
    const std::vector<bool> &input_secure = {}
) { return _::run(0, timeout, priority, title, body_text, primary, secondary, tertiary_text, input_titles, input_secure); }

inline _::result priority(
    const std::string &title,
    int priority_level,
    const std::string &body_text = "",
    const std::string &primary = "",
    const std::string &secondary = "",
    const std::string &tertiary = "",
    double timeout = 0,
    const std::vector<std::string> &input_titles = {},
    const std::vector<bool> &input_secure = {}
) { return _::run(0, timeout, priority_level, title, body_text, primary, secondary, tertiary, input_titles, input_secure); }

inline _::result timeout(
    const std::string &title,
    double timeout_seconds,
    const std::string &body_text = "",
    const std::string &primary = "",
    const std::string &secondary = "",
    const std::string &tertiary = "",
    int priority = kCFUserNotificationNoteAlertLevel,
    const std::vector<std::string> &input_titles = {},
    const std::vector<bool> &input_secure = {}
) { return _::run(0, timeout_seconds, priority, title, body_text, primary, secondary, tertiary, input_titles, input_secure); }

inline _::result input(
    const std::string &title,
    const std::string &input_title,
    const std::string &body_text = "",
    const std::string &primary = "",
    const std::string &secondary = "",
    const std::string &tertiary = "",
    double timeout = 0,
    int priority = kCFUserNotificationNoteAlertLevel
) { return _::run(0, timeout, priority, title, body_text, primary, secondary, tertiary, {input_title}, {false}); }

inline _::result secure(
    const std::string &title,
    const std::string &secure_prompt,
    const std::string &body_text = "",
    const std::string &primary = "",
    const std::string &secondary = "",
    const std::string &tertiary = "",
    double timeout = 0,
    int priority = kCFUserNotificationNoteAlertLevel
) { return _::run(0, timeout, priority, title, body_text, primary, secondary, tertiary, {secure_prompt}, {true}); }

inline _::result json(
    const std::string &title,
    const std::string &body_text = "",
    const std::string &primary = "",
    const std::string &secondary = "",
    const std::string &tertiary = "",
    double timeout = 0,
    int priority = kCFUserNotificationNoteAlertLevel,
    const std::vector<std::string> &input_titles = {},
    const std::vector<bool> &input_secure = {}
) { return _::run(0, timeout, priority, title, body_text, primary, secondary, tertiary, input_titles, input_secure, true); }
} /* namespace a1::bin::uialert */

