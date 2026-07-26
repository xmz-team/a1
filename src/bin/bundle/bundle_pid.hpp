#pragma once

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <sys/sysctl.h>
#include "libproc.h"
#include "libproc_internal.h"
#include "libproc_private.h"
#include <libxmz/io.hpp>

/**
 * Find the corresponding PID according to the Bundle ID or process name
 * @param target target identifier (Bundle ID such as "com.apple.Safari", or process name such as "Safari")
 * @return found PID, not found return -1
 */

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

extern "C" {
int bundle_pid(const char *target);
}

namespace a1::bin::_bundle_pid {
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

int findPIDByBundle(const char *target) {
    @autoreleasepool {
        if (!target) return -1;
        NSString *targetInput = [NSString stringWithUTF8String:target];
        /* Get the list of processes */
        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
        size_t size;
        sysctl(mib, 4, NULL, &size, NULL, 0);
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
                free(procs); return pid;
            }
            /* Signature matching */
            if (checkSignature(fullPath, targetInput)) {
                free(procs); return pid;
            }
            /* Upward tracing feature identification */
            NSString *currentPath = [fullPath stringByDeletingLastPathComponent];
            int depth = 0;
            while (currentPath.length > 1 && depth < 5) {
                NSString *ext = [[currentPath pathExtension] lowercaseString];
                /* If this directory has the Bundle suffix, just check it. */
                if (ext.length > 0 && [validExtensions containsObject:ext]) {
                    if (checkSignature(currentPath, targetInput)) {
                        free(procs); return pid;
                    }
                    /* Once you enter the Bundle directory (regardless of whether the ID matches), stop climbing upwards. */
                    break;
                }
                currentPath = [currentPath stringByDeletingLastPathComponent];
                depth++;
            }
        }
        free(procs);
        return -1;
    }
}

} // namespace a1::bin::_bundle_pid

#ifdef __cplusplus
namespace a1::bin {
extern "C" int bundle_pid(const char *target) {
    return a1::bin::_bundle_pid::findPIDByBundle(target);
}
#endif
} /* namespace a1::bin */
