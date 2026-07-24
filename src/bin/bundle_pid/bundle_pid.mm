/*
 *  bundle_pid.m
 *  Added support for Bundle Identifier by XMZ <ad-ios334@outlook.com> on 5/12/25
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
// c++ -fobjc-arc -framework Foundation -framework Security -I. bundle_pid.mm -o bundle_pid && ldid -S../a1.bin.ens.xml -Hsha1 -Hsha256 -M  bundle_pid

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <sys/sysctl.h>
#include "libproc.h"
#include "libproc_internal.h"
#include "libproc_private.h"
#include <libxmz/io.hpp>

/* Security API Declaration */
typedef struct __SecCode const *SecStaticCodeRef;
typedef uint32_t SecCSFlags;
enum { kSecCSDefaultFlags = 0 };
extern const CFStringRef kSecCodeInfoIdentifier;
extern const CFStringRef kSecCodeInfoPList;

#ifdef __cplusplus
extern "C" {
#endif
OSStatus SecStaticCodeCreateWithPath(CFURLRef path, SecCSFlags flags, SecStaticCodeRef *staticCode);
OSStatus SecCodeCopySigningInformation(SecStaticCodeRef code, SecCSFlags flags, CFDictionaryRef *information);
#ifdef __cplusplus
}
#endif

/* Signature check core */
BOOL checkSignature(NSString *path, NSString *targetID) {
    if (!path || !targetID) return NO;
    NSURL *url = [NSURL fileURLWithPath:path];
    SecStaticCodeRef staticCode = NULL;
    BOOL match = NO;

    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)url, kSecCSDefaultFlags, &staticCode) == 0) {
        CFDictionaryRef info = NULL;
        if (SecCodeCopySigningInformation(staticCode, kSecCSDefaultFlags, &info) == 0) {
            NSString *signID = (__bridge NSString *)CFDictionaryGetValue(info, kSecCodeInfoIdentifier);
            if (signID && [signID caseInsensitiveCompare:targetID] == NSOrderedSame) match = YES;
            
            if (!match) {
                NSDictionary *plist = (__bridge NSDictionary *)CFDictionaryGetValue(info, kSecCodeInfoPList);
                if (plist && plist[@"CFBundleIdentifier"] && [plist[@"CFBundleIdentifier"] caseInsensitiveCompare:targetID] == NSOrderedSame) match = YES;
            }
            CFRelease(info);
        }
        CFRelease(staticCode);
    }
    return match;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) return -1;
        NSString *targetInput = [NSString stringWithUTF8String:argv[1]];

        /* Get the list of processes */
        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
        size_t size;
        sysctl(mib, 4, NULL, &size, NULL, 0);
        // struct kinfo_proc *procs = malloc(size);
        struct kinfo_proc *procs = static_cast<struct kinfo_proc *>(malloc(size));
        sysctl(mib, 4, procs, &size, NULL, 0);
        int count = size / sizeof(struct kinfo_proc);

        /* Define the Bundle suffix */
        NSSet *validExtensions = [NSSet setWithArray:@[@"app", @"framework", @"bundle", @"xpc", @"plugin", @"dylib", @"appex"]];

        for (int i = 0; i < count; i++) {
            pid_t pid = procs[i].kp_proc.p_pid;
            if (pid <= 0) continue;

            char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
            if (proc_pidpath(pid, pathBuffer, sizeof(pathBuffer)) <= 0) continue;
            
            NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];
            
            /* Document name matching */
            if ([[fullPath lastPathComponent] caseInsensitiveCompare:targetInput] == NSOrderedSame) {
                xmz::print(pid); free(procs); return 0;
            }

            /* Signature matching */
            if (checkSignature(fullPath, targetInput)) {
                xmz::print(pid); free(procs); return 0;
            }

            /* Upward tracing feature identification */
            NSString *currentPath = [fullPath stringByDeletingLastPathComponent];
            int depth = 0;
            while (currentPath.length > 1 && depth < 5) {
                NSString *ext = [[currentPath pathExtension] lowercaseString];
                
                /* If this directory has the Bundle suffix, just check it. */
                if (ext.length > 0 && [validExtensions containsObject:ext]) {
                    if (checkSignature(currentPath, targetInput)) {
                        xmz::print(pid); free(procs); return 0;
                    }
                    /* Once you enter the Bundle directory (regardless of whether the ID matches), stop climbing upwards. */
                    break;
                }
                
                currentPath = [currentPath stringByDeletingLastPathComponent];
                depth++;
            }
        }
        free(procs);
        xmz::print("-1");
    }
    return 0;
}
