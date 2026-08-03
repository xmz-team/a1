// set_defaults.hpp
#pragma once
#include <string>
#include <cstdlib>
#include <unordered_map>
#include <a1/core/myini.hpp>
#include <a1/core/config.hpp>

namespace a1::_coreapi {
struct set_defaults_config {
    int high_priority = 39;
    int low_priority = 0;
    int launchd_priority = 20;
    int jetsam_priority = 15;
    int max_cpu_percent = 15;
    // mode on/off
    bool loop_mode = false;
    bool auto_adjust = false;
    bool scheduled_guard = false;
    bool experimental = false;
    bool log_reincarnation = false;
    bool custom_priority_enabled = false;
    bool debug_mode = true;
    bool module_switch = false;
    // gap set
    int optimize_interval = 1800;
    int loop_sleep_interval = 5;
    // Permission set
    bool use_sudo_all = true;
    bool use_sudo_a1 = true;
    bool use_sudo_a1ctl = true;
    bool use_root_a1ctl = true;
    // other
    bool compat_mode = false;
    bool lock_use = true;
    bool dynamic_optimization = false;
};

inline set_defaults_config& get_config() {
    static set_defaults_config config;
    return config;
}

inline std::string config_text = []() -> std::string {
    return R"(#config.ini

#Priority configuration
high_priority = 0
low_priority = 39
launchd_priority = 20
jetsam_priority = 15

#mode on/off
loop_mode = false
auto_adjust = false
auto_apply = false
scheduled_guard = false
#experimental = false
log_reincarnation = false
custom_priority_enabled = false
debug_mode = true
module_switch = false

#gap set
optimize_interval = 1800
loop_sleep_interval = 5

#permission set
#use_sudo_all = false
#use_sudo_a1 = false
#use_sudo_a1ctl = false
#use_root_a1ctl = false

#other
compat_mode = false
lock_use = true
dynamic_optimization = false

)";
}();
} /* namespace a1::_coreapi */

namespace a1::coreapi {
inline void set_defaults() {
    auto& g_config = a1::_coreapi::get_config();

    a1::config::jb_path g_jb;
    std::string config_path = g_jb.a1config + "/config.ini";

    a1::ini::ini_parser parser;
    bool has_config_file = parser.parse_file(config_path);

    auto get_config_int = [&](const char* key, int default_val) -> int {
        if (!has_config_file) return default_val;
        return parser.get_int("", key, default_val);
    };

    auto get_config_bool = [&](const char* key, bool default_val) -> bool {
        if (!has_config_file) return default_val;
        return parser.get_bool("", key, default_val);
    };

    // read all configuration items
    g_config.high_priority       = get_config_int("high_priority", 30);
    g_config.low_priority        = get_config_int("low_priority", 10);
    g_config.launchd_priority    = get_config_int("launchd_priority", 20);
    g_config.jetsam_priority     = get_config_int("jetsam_priority", 15);
    g_config.max_cpu_percent     = get_config_int("max_cpu_percent", 15);
    g_config.optimize_interval   = get_config_int("optimize_interval", 1800);
    g_config.loop_sleep_interval = get_config_int("loop_sleep_interval", 5);

    g_config.loop_mode                = get_config_bool("loop_mode", false);
    g_config.auto_adjust              = get_config_bool("auto_adjust", false);
    g_config.scheduled_guard          = get_config_bool("scheduled_guard", false);
    g_config.experimental             = get_config_bool("experimental", false);
    g_config.log_reincarnation        = get_config_bool("log_reincarnation", false);
    g_config.custom_priority_enabled  = get_config_bool("custom_priority_enabled", false);
    g_config.debug_mode               = get_config_bool("debug_mode", true);
    g_config.module_switch            = get_config_bool("module_switch", false);
    g_config.use_sudo_all             = get_config_bool("use_sudo_all", true);
    g_config.use_sudo_a1              = get_config_bool("use_sudo_a1", true);
    g_config.use_sudo_a1ctl           = get_config_bool("use_sudo_a1ctl", true);
    g_config.use_root_a1ctl           = get_config_bool("use_root_a1ctl", true);
    g_config.compat_mode              = get_config_bool("compat_mode", false);
    g_config.lock_use                 = get_config_bool("lock_use", true);
    g_config.dynamic_optimization     = get_config_bool("dynamic_optimization", false);
}

inline const _coreapi::set_defaults_config& set_defaults_cfg() { return _coreapi::get_config(); }

inline std::string cfg_text = []() -> std::string { return _coreapi::config_text; }();

} /* namespace a1::coreapi */
