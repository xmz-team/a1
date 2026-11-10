/*
 * CFUserNotification.hpp
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

/* Apple does not allow it to be used in iOS SDK, and can only be declared manually. */

#if !defined(__COREFOUNDATION_CFUSERNOTIFICATION__)
#define __COREFOUNDATION_CFUSERNOTIFICATION__ 1
#include <stdint.h>
typedef unsigned long  CFTypeID;
typedef unsigned long  CFOptionFlags;
typedef signed   long  CFIndex;
typedef int32_t        SInt32;
typedef unsigned char  Boolean;
typedef double         CFTimeInterval;
typedef double         CFAbsoluteTime;
typedef const void                *CFTypeRef;
typedef const struct __CFAllocator *CFAllocatorRef;
typedef const struct __CFString    *CFStringRef;
typedef const struct __CFDictionary *CFDictionaryRef;
typedef       struct __CFDictionary *CFMutableDictionaryRef;
typedef       struct __CFUserNotification *CFUserNotificationRef;

extern "C" {
CFUserNotificationRef CFUserNotificationCreate(CFAllocatorRef  allocator,
                                               CFTimeInterval  timeout,
                                               CFOptionFlags   flags,
                                               SInt32          *error,
                                               CFDictionaryRef dictionary);

SInt32 CFUserNotificationReceiveResponse(CFUserNotificationRef userNotification,
                                         CFTimeInterval timeout,
                                         CFOptionFlags *responseFlags);

CFDictionaryRef CFUserNotificationGetResponseDictionary(CFUserNotificationRef userNotification);

void CFRelease(CFTypeRef cf);

extern const CFStringRef kCFUserNotificationAlertHeaderKey;
extern const CFStringRef kCFUserNotificationAlertMessageKey;
extern const CFStringRef kCFUserNotificationDefaultButtonTitleKey;
extern const CFStringRef kCFUserNotificationAlternateButtonTitleKey;
extern const CFStringRef kCFUserNotificationOtherButtonTitleKey;
extern const CFStringRef kCFUserNotificationTextFieldTitlesKey;
extern const CFStringRef kCFUserNotificationTextFieldValuesKey;
} /* extern "C" */

constexpr CFOptionFlags kCFUserNotificationStopAlertLevel    = 0;
constexpr CFOptionFlags kCFUserNotificationNoteAlertLevel    = 1;
constexpr CFOptionFlags kCFUserNotificationCautionAlertLevel = 2;
constexpr CFOptionFlags kCFUserNotificationPlainAlertLevel   = 3;

constexpr CFOptionFlags kCFUserNotificationDefaultResponse   = 0;
constexpr CFOptionFlags kCFUserNotificationAlternateResponse = 1;
constexpr CFOptionFlags kCFUserNotificationOtherResponse     = 2;
constexpr CFOptionFlags kCFUserNotificationCancelResponse    = 3;

constexpr CFOptionFlags kCFUserNotificationNoDefaultButtonFlag = (1UL << 5);
constexpr CFOptionFlags kCFUserNotificationUseRadioButtonsFlag = (1UL << 6);

static inline CFOptionFlags CFUserNotificationSecureTextField(CFIndex i) { return (CFOptionFlags)(1UL << (16 + i)); }
static inline CFOptionFlags CFUserNotificationCheckBoxChecked(CFIndex i) { return (CFOptionFlags)(1UL << (8 + i)); }
static inline CFOptionFlags CFUserNotificationPopUpSelection(CFIndex n)  { return (CFOptionFlags)(n << 24); }
#endif /* ! __COREFOUNDATION_CFUSERNOTIFICATION__ */
