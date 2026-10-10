// version.hpp
#pragma once
#include <string_view>
#include <string>
namespace a1::_coreapi::version {
    inline constexpr std::string_view a1    = "2.0.0.302";
    inline constexpr std::string_view a1ctl = "2.0.0.214";
    inline constexpr std::string_view a1mod = "2.0.0.214";
    inline constexpr std::string_view a1pm  = "2.0.0.203";
    inline constexpr std::string_view a1gui = "@gui_version@";
    inline constexpr std::string_view gui = a1gui;
    inline constexpr std::string_view general = "2.0.1.99";
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
