#include <string>
#include <cstdlib>
#include <unordered_map>

namespace a1::_coreapi {
struct set_defaults_config {
    // high default value
    int high_priority = 0;
    int low_priority = 39;
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
} /* namespace a1::_coreapi */

namespace a1::coreapi {
void set_defaults() {
    _coreapi::set_defaults_config g_config;
    auto get_env_int = [](const char* name, int default_val) -> int
    {
        const char* env = std::getenv(name);
        return env ? std::stoi(env) : default_val;
    };

    auto get_env_bool = [](const char* name, bool default_val) -> bool
    {
        const char* env = std::getenv(name);
        if (!env) return default_val;
        std::string val(env);
        return val == "true" || val == "1" || val == "yes";
    };

    // high default value
    g_config.high_priority = get_env_int("HIGH_PRIORITY", 0);
    g_config.low_priority = get_env_int("LOW_PRIORITY", 39);
    g_config.launchd_priority = get_env_int("LAUNCHD_PRIORITY", 20);
    g_config.jetsam_priority = get_env_int("JETSAM_PRIORITY", 15);
    g_config.max_cpu_percent = get_env_int("MAX_CPU_PERCENT", 15);
    // gap set
    g_config.optimize_interval = get_env_int("OPTIMIZE_INTERVAL", 1800);
    g_config.loop_sleep_interval = get_env_int("LOOP_SLEEP_INTERVAL", 5);

    // mode on/off
    g_config.loop_mode = get_env_bool("LOOP_MODE", false);
    g_config.auto_adjust = get_env_bool("AUTO_ADJUST", false);
    g_config.scheduled_guard = get_env_bool("SCHEDULED_GUARD", false);
    g_config.experimental = get_env_bool("EXPERIMENTAL", false);
    g_config.log_reincarnation = get_env_bool("LOG_REINCARNATION", false);
    g_config.custom_priority_enabled = get_env_bool("CUSTOM_PRIORITY_ENABLED", false);
    g_config.debug_mode = get_env_bool("DEBUG_MODE", true);
    // Permission set
    g_config.use_sudo_all = get_env_bool("USE_SUDO_ALL", true);
    g_config.use_sudo_a1 = get_env_bool("USE_SUDO_A1", true);
    g_config.use_sudo_a1ctl = get_env_bool("USE_SUDO_A1CTL", true);
    g_config.use_root_a1ctl = get_env_bool("USE_ROOT_A1CTL", true);
    // other
    g_config.compat_mode = get_env_bool("COMPAT_MODE", false);
    g_config.lock_use = get_env_bool("LOCK_USE", true);
    g_config.dynamic_optimization = get_env_bool("DYNAMIC_OPTIMIZATION", false);
}
} /* namespace a1::coreapi */