// version.hpp
#pragma once
#include <string>
namespace a1::_coreapi::version {
    std::string a1_version = "2.0.0.254";
    std::string a1ctl_version = "2.0.0.166";
    std::string a1mod_version = "2.0.0.166";
    std::string a1pm_version = "2.0.0.155";
}

namespace a1::_coreapi {
    inline const std::string& a1_version = a1::_coreapi::version::a1;
    inline const std::string& a1ctl_version = a1::_coreapi::version::a1ctl;
    inline const std::string& a1mod_version = a1::_coreapi::version::a1mod;
    inline const std::string& a1pm_version = a1::_coreapi::version::a1pm;
}

namespace a1::version {
    inline const std::string& a1 = a1::_coreapi::version::a1_version;
    inline const std::string& a1ctl = a1::_coreapi::version::a1ctl_version;
    inline const std::string& a1mod = a1::_coreapi::version::a1mod_version;
    inline const std::string& a1pm = a1::_coreapi::version::a1pm_version;
}
