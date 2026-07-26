#include "bundle_pid.hpp"
namespace a1::bin {
extern "C" const char* pid_bundle(int pid) {
    @autoreleasepool {
        if (pid <= 0) return NULL;
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_pidpath(pid, pathBuffer, sizeof(pathBuffer)) <= 0) return NULL;
        NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];
        // try to get the signature information of the main executable file directlygnature information of the main executable file directly
        NSURL *url = [NSURL fileURLWithPath:fullPath];
        SecStaticCodeRef staticCode = NULL;
        if (SecStaticCodeCreateWithPath((__bridge CFURLRef)url, kSecCSDefaultFlags, &staticCode) == 0) {
            CFDictionaryRef info = NULL;
            if (SecCodeCopySigningInformation(staticCode, kSecCSDefaultFlags, &info) == 0) {
                NSString *signID = (__bridge NSString *)CFDictionaryGetValue(info, kSecCodeInfoIdentifier);
                if (signID) {
                    const char *result = strdup([signID UTF8String]);
                    CFRelease(info);
                    CFRelease(staticCode);
                    return result;
                }
                NSDictionary *plist = (__bridge NSDictionary *)CFDictionaryGetValue(info, kSecCodeInfoPList);
                if (plist && plist[@"CFBundleIdentifier"]) {
                    const char *result = strdup([plist[@"CFBundleIdentifier"] UTF8String]);
                    CFRelease(info);
                    CFRelease(staticCode);
                    return result;
                }
                CFRelease(info);
            }
            CFRelease(staticCode);
        }
        NSSet *validExtensions = [NSSet setWithArray:@[@"app", @"framework", @"bundle", @"xpc", @"plugin", @"dylib", @"appex"]];
        NSString *currentPath = [fullPath stringByDeletingLastPathComponent];
        int depth = 0;
        while (currentPath.length > 1 && depth < 5) {
            NSString *ext = [[currentPath pathExtension] lowercaseString];
            if (ext.length > 0 && [validExtensions containsObject:ext]) {
                NSURL *bundleURL = [NSURL fileURLWithPath:currentPath];
                SecStaticCodeRef bundleCode = NULL;
                if (SecStaticCodeCreateWithPath((__bridge CFURLRef)bundleURL, kSecCSDefaultFlags, &bundleCode) == 0) {
                    CFDictionaryRef bundleInfo = NULL;
                    if (SecCodeCopySigningInformation(bundleCode, kSecCSDefaultFlags, &bundleInfo) == 0) {
                        NSString *signID = (__bridge NSString *)CFDictionaryGetValue(bundleInfo, kSecCodeInfoIdentifier);
                        if (signID) {
                            const char *result = strdup([signID UTF8String]);
                            CFRelease(bundleInfo);
                            CFRelease(bundleCode);
                            return result;
                        }
                        NSDictionary *plist = (__bridge NSDictionary *)CFDictionaryGetValue(bundleInfo, kSecCodeInfoPList);
                        if (plist && plist[@"CFBundleIdentifier"]) {
                            const char *result = strdup([plist[@"CFBundleIdentifier"] UTF8String]);
                            CFRelease(bundleInfo);
                            CFRelease(bundleCode);
                            return result;
                        }
                        CFRelease(bundleInfo);
                    }
                    CFRelease(bundleCode);
                }
                break;
            }
            currentPath = [currentPath stringByDeletingLastPathComponent];
            depth++;
        }
        NSString *processName = [fullPath lastPathComponent];
        return strdup([processName UTF8String]);
    }
}
} /* namespace a1::bin */
