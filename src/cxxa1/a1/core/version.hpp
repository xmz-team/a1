// version.hpp
#pragma once
#include <string_view>
#include <string>
namespace a1::_coreapi::version {
    inline constexpr std::string_view a1    = "2.0.0.294";
    inline constexpr std::string_view a1ctl = "2.0.0.206";
    inline constexpr std::string_view a1mod = "2.0.0.206";
    inline constexpr std::string_view a1pm  = "2.0.0.195";
}

namespace a1::version {
    using _coreapi::version::a1;
    using _coreapi::version::a1ctl;
    using _coreapi::version::a1mod;
    using _coreapi::version::a1pm;
}
