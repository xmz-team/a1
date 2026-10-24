// open.hpp
#pragma once
#include <string>
#include <CoreFoundation/CoreFoundation.h>

namespace a1ctl {
    extern "C" int SBSLaunchApplicationWithIdentifier(CFStringRef identifier, Boolean suspended);

    inline int open_app_by_bundleid(const char* bundle_id) {
        if (!bundle_id) return 1;
        CFStringRef bid = CFStringCreateWithCString(kCFAllocatorDefault, bundle_id, kCFStringEncodingUTF8);
        if (!bid) return 1;
        int ret = SBSLaunchApplicationWithIdentifier(bid, false);
        CFRelease(bid);
        return ret;
    }

    inline int open_app_by_bundleid(const std::string& bundle_id) { return open_app_by_bundleid(bundle_id.c_str()); }
} // namespace a1ctl
