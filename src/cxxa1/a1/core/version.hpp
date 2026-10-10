// version.hpp
#pragma once
#include <string_view>
#include <string>
namespace a1::_coreapi::version {
    inline constexpr std::string_view a1    = "2.0.0.299";
    inline constexpr std::string_view a1ctl = "2.0.0.211";
    inline constexpr std::string_view a1mod = "2.0.0.211";
    inline constexpr std::string_view a1pm  = "2.0.0.200";
    inline constexpr std::string_view a1gui = "@gui_version@";
    inline constexpr std::string_view gui = a1gui;
    inline constexpr std::string_view general = "2.0.1.96";
}

namespace a1::version {
    using _coreapi::version::a1;
    using _coreapi::version::a1ctl;
    using _coreapi::version::a1mod;
    using _coreapi::version::a1pm;
    using _coreapi::version::a1gui;
    using _coreapi::version::gui;
    using _coreapi::version::general;
}
