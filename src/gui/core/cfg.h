// cfg.h
#pragma once
#include "env.h"
#include <string>
#import <Foundation/Foundation.h>

namespace a1gui {
    namespace _locale {
        inline NSString* locale(const std::string& key, const std::string& annotate = "") { return NSLocalizedString([NSString stringWithUTF8String:key.c_str()], [NSString stringWithUTF8String:annotate.c_str()]); }
    } /* namespace _locale */

    inline NSString* locale(const std::string& key, const std::string& ann) { return _locale::locale(key, ann); }
    inline NSString* locale(const std::string& key) { return _locale::locale(key, ""); }

} /* namespace a1gui */
