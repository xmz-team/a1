/*
 *  bundle_pid.m
 *  bundle_pid
 *  Added support for Bundle Identifier by AD on 5/12/25
 *  Copyright (c) 2025 AD All rights reserved.
 */
/*
 *
 * @(Compilation command): clang -fobjc-arc -framework Foundation -framework Security -Iinclude bundle_pid.m -o bundle_pid && ldid -Sentitlements.plist bundle_pid
 *
**/

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <sys/sysctl.h>
#include "include/libproc.h"

/* Security API 聲明 */
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

/* 簽名檢查核心 */
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

        /* 獲取進程列表 */
        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
        size_t size;
        sysctl(mib, 4, NULL, &size, NULL, 0);
        struct kinfo_proc *procs = malloc(size);
        sysctl(mib, 4, procs, &size, NULL, 0);
        int count = size / sizeof(struct kinfo_proc);

        /* 定義 Bundle 後綴 (碰到這些會停下來檢查) */
        NSSet *validExtensions = [NSSet setWithArray:@[@"app", @"framework", @"bundle", @"xpc", @"plugin", @"dylib"]];

        for (int i = 0; i < count; i++) {
            pid_t pid = procs[i].kp_proc.p_pid;
            if (pid <= 0) continue;

            char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
            if (proc_pidpath(pid, pathBuffer, sizeof(pathBuffer)) <= 0) continue;
            
            NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];
            
            /* 文檔名匹配 */
            if ([[fullPath lastPathComponent] caseInsensitiveCompare:targetInput] == NSOrderedSame) {
                printf("%d", pid); free(procs); return 0;
            }

            /* 簽名匹配 */
            if (checkSignature(fullPath, targetInput)) {
                printf("%d", pid); free(procs); return 0;
            }

            /* 向上追溯特徵識別 */
            NSString *currentPath = [fullPath stringByDeletingLastPathComponent];
            int depth = 0;
            while (currentPath.length > 1 && depth < 5) {
                NSString *ext = [[currentPath pathExtension] lowercaseString];
                
                /* 如果這個目錄有 Bundle 後綴，才去檢查 */
                if (ext.length > 0 && [validExtensions containsObject:ext]) {
                    if (checkSignature(currentPath, targetInput)) {
                        printf("%d", pid); free(procs); return 0;
                    }
                    /* 只要進了 Bundle 目錄(不管 ID 配不配), 就該停止向上爬了 */
                    break;
                }
                
                currentPath = [currentPath stringByDeletingLastPathComponent];
                depth++;
            }
        }
        free(procs);
        printf("-1");
    }
    return 0;
}
