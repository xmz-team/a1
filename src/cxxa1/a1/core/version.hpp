// version.hpp
#pragma once
#include <string>
namespace a1::_coreapi::version {
    std::string a1_version = "2.0.0.211";
    std::string a1ctl_version = "2.0.0.123";
    std::string a1mod_version = "2.0.0.123";
    std::string a1pm_version = "2.0.0.112";
}

namespace a1::_coreapi {
    using a1::_coreapi::version::a1_version;
    using a1::_coreapi::version::a1ctl_version;
    using a1::_coreapi::version::a1mod_version;
    using a1::_coreapi::version::a1pm_version;
}

namespace a1::version {
    std::string a1 = a1::_coreapi::version::a1_version;
    std::string a1ctl = a1::_coreapi::version::a1ctl_version;
    std::string a1mod = a1::_coreapi::version::a1mod_version;
    std::string a1pm = a1::_coreapi::version::a1pm_version;
}
