// cxxa1ctl.cc
#include <a1/core/a1ctlcore.hpp>
#include <a1/core/version.hpp>
#include <a1/core/lock.hpp>
#include <a1/core/myini.hpp>

#include <libxmz/log.hpp>
#include <libxmz/io.hpp>

#include <string>
#include <string_view>
#include <optional>
#include <functional>
#include <unordered_map>
#include <vector>
#include <cstdlib>
#include <unistd.h>

inline std::string help_text(const std::string& myself) {
    return std::string(R"(
  __    _       _     _     ___  
 / /\  / |     | |_| | | | | |_) 
/_/--\ |_|     |_| | \_\_/ |_|_) 

Author: LF | Maintainer: LF, AD, XMZ, amzxus
Organization(QQ): 1030152896
)") + "Usage: " + myself + " [options] [command]" + R"(
Basic Commands:
  start                    Start A1
  stop                     Stop A1
  status                   View status
  restart                  Restart A1

Mode Control:
  loop <on|off>            Enable/disable loop mode
  auto-adjust <on|off>     Enable/disable real-time auto-adjust mode (1s polling)
  scheduled-guard <on|off> Enable/disable scheduled guard mode (15s polling)
  custom <on|off>          Enable/disable custom priority

Priority Management:
  add high <process>       Add to high priority list
  add low <process>        Add to low priority list
  add <process> <value>    Add custom priority (0-99)
  remove <process>         Remove from priority list
  list <high|low|custom>   View priority list
  clear <high|low|custom>  Clear priority list
  set <type> <value>       Set priority value

  type: high, low, launchd*
  value: 0-39 (Jetsam value)

Configuration Management:
  config                   View current configuration
  set-interval <seconds>   Set optimization interval
  loop-sleep <seconds>     Set loop interval
  auto-apply <on|off>      Enable/disable auto-apply
  restore                  Restore configuration from backup
  compat <on|off>          Enable/disable compatibility mode
  mod-switch <on|off>      Enable/turn off the mod mode
  lock <on|off>            Enable/disable lock

Other:
  help                     Show this help
  version                  Show Version
  -f                       Forced start/foreground mode

Tips:
  Real-time auto-adjust mode: Check new processes every second and adjust priority (more aggressive)
  Scheduled guard mode: Check every 15 seconds (more battery efficient)
  Loop mode: Traditional mode, periodically execute full optimization
  -20=Highest (Jetsam 0)
  0=Default
  19=Lowest (Jetsam 39)
  Default priority is determined by the launchd process
)";
}

inline a1ctl::lock_manager g_lock_mgr;
inline void signal_handler(int sig) {
    xmz::log::info("received the signal", sig, "is cleaning up and exiting...");
    g_lock_mgr.release();
    exit(128 + sig);
}

struct args {
    int argc;
    char** argv;
    std::string_view at(int i) const {
        if (i < 0 || i >= argc || argv[i] == nullptr) return {};
        return std::string_view(argv[i]);
    }
    bool has(int i) const { return i >= 0 && i < argc && argv[i] != nullptr; }
};

inline bool need_args(const args& a, int need, const char* usage) {
    if (a.argc < need) {
        xmz::log::error("usage: ", usage);
        return false;
    }
    return true;
}

inline std::optional<bool> parse_onoff(std::string_view v) {
    if (v == "on")  return true;
    if (v == "off") return false;
    return std::nullopt;
}

inline std::optional<int> parse_int(std::string_view v) {
    if (v.empty()) return std::nullopt;
    try {
        size_t pos = 0;
        int r = std::stoi(std::string(v), &pos);
        if (pos != v.size()) return std::nullopt;
        return r;
    } catch (...) {
        return std::nullopt;
    }
}

namespace cmd {
inline int switch_exclusive_mode(const args& a,
                                 const char* on_key,
                                 const char* off_key,
                                 const std::vector<const char*>& others,
                                 const char* usage,
                                 const char* on_msg,
                                 const char* off_msg) {
    if (!need_args(a, 3, usage)) return 1;
    auto v = parse_onoff(a.at(2));
    if (!v) { xmz::log::error("usage: ", usage); return 1; }
    if (*v) {
        a1ctl::update_config(on_key, true);
        for (auto k : others) a1ctl::update_config(k, false);
        xmz::log::info(on_msg, " (other modes have been turned off automatically)");
    } else {
        if (off_key) a1ctl::update_config(off_key, false);
        else         a1ctl::update_config(on_key, false);
        xmz::log::info(off_msg);
    }
    return 0;
}

struct add_args {
    std::string type;     // "h" / "l" / "c"
    std::string process;
    int         value{};  // only custom
};

inline std::optional<add_args> parse_add(const args& a) {
    // add high|h <process>
    // add low |l <process>
    // add custom|c <process> <value>
    // add <process> <value>
    if (!a.has(2)) return std::nullopt;
    const auto p2 = a.at(2);
    auto read_value = [&](int idx) -> std::optional<int> {
        auto v = parse_int(a.at(idx));
        if (!v || *v < 0 || *v > 99) return std::nullopt;
        return v;
    };

    if (p2 == "high" || p2 == "h") {
        if (!a.has(3)) return std::nullopt;
        return add_args{"h", std::string(a.at(3)), 0};
    }
    if (p2 == "low" || p2 == "l") {
        if (!a.has(3)) return std::nullopt;
        return add_args{"l", std::string(a.at(3)), 0};
    }
    if (p2 == "custom" || p2 == "c") {
        if (!a.has(4)) return std::nullopt;
        auto v = read_value(4);
        if (!v) return std::nullopt;
        return add_args{"c", std::string(a.at(3)), *v};
    }

    if (!a.has(3)) return std::nullopt;
    auto v = read_value(3);
    if (!v) return std::nullopt;
    return add_args{"c", std::string(p2), *v};
}

inline int handle_add(const args& a) {
    if (!need_args(a, 3,
        "add <high|low> <process> | add custom <process> <value> | add <process> <value>")) return 1;

    auto parsed = parse_add(a);
    if (!parsed) {
        xmz::log::error("invalid arguments for add");
        xmz::log::error("usage: add <high|low> <process> | add custom <process> <value> | add <process> <value>");
        return 1;
    }

    auto& g_cfg = a1::coreapi::get_cfg();
    if (parsed->type == "h") a1ctl::add_priority("h", parsed->process, g_cfg.high_priority);
    else if (parsed->type == "l") a1ctl::add_priority("l", parsed->process, g_cfg.low_priority);
    else a1ctl::add_priority("c", parsed->process, parsed->value);
    return 0;
}

inline int handle_remove(const args& a) {
    if (!need_args(a, 3, "remove <high|low|custom> <process> | remove <process>")) return 1;
    const auto p2 = a.at(2);
    auto rm = [&](const char* kind, std::string_view proc) -> int {
        if (proc.empty()) { xmz::log::error("the process name cannot be empty."); return 1; }
        a1ctl::remove_priority(kind, std::string(proc));
        return 0;
    };

    if (p2 == "high" || p2 == "h")   return rm("high",   a.at(3));
    if (p2 == "low" || p2 == "l")    return rm("low",    a.at(3));
    if (p2 == "custom" || p2 == "c") return rm("custom", a.at(3));

    a1ctl::remove_priority("high",   std::string(p2));
    a1ctl::remove_priority("low",    std::string(p2));
    a1ctl::remove_priority("custom", std::string(p2));
    return 0;
}

inline int handle_list(const args& a) {
    if (!need_args(a, 3, "list <high|low|custom>")) return 1;
    a1ctl::list_priority(std::string(a.at(2)));
    return 0;
}

inline int handle_clear(const args& a) {
    if (!need_args(a, 3, "clear <high|low|custom>")) return 1;
    a1ctl::clear_priority(std::string(a.at(2)));
    return 0;
}

inline int handle_set(const args& a) {
    if (!need_args(a, 4, "set <high|low|launchd> <value>")) return 1;
    auto v = parse_int(a.at(3));
    if (!v) { xmz::log::error("invalid priority value:", std::string(a.at(3))); return 1; }
    return a1ctl::set_priority_value(std::string(a.at(2)), *v);
}

} /* namespace cmd */

using handler = std::function<int(const args&)>;
using cmd_table = std::unordered_map<std::string_view, handler>;

inline cmd_table build_commands() {
    cmd_table t;
    t["start"] = t["1"] = [](const args&) -> int {
        a1ctl::start_a1();
        return 0;
    };

    t["stop"] = t["0"] = [](const args&) -> int {
        a1::kill_pid();
        xmz::log::info("A1 has stopped");
        return 0;
    };

    t["restart"] = [](const args&) -> int {
        a1::kill_pid();
        sleep(2);
        a1ctl::start_a1();
        return 0;
    };

    t["status"] = [](const args&) -> int {
        a1ctl::check_status();
        return 0;
    };

    t["loop"] = [](const args& a) -> int {
        return cmd::switch_exclusive_mode(
            a,
            "loop_mode", nullptr,
            {"auto_adjust", "scheduled_guard"},
            "loop <on|off>",
            "loop mode is on",
            "loop mode is off");
    };

    t["auto-adjust"] = [](const args& a) -> int {
        return cmd::switch_exclusive_mode(
            a,
            "auto_adjust", nullptr,
            {"loop_mode", "scheduled_guard"},
            "auto-adjust <on|off>",
            "real-time auto-adjust mode is on",
            "real-time auto-adjust mode is off");
    };

    t["scheduled-guard"] = t["guard"] = [](const args& a) -> int {
        return cmd::switch_exclusive_mode(
            a,
            "scheduled_guard", nullptr,
            {"loop_mode", "auto_adjust"},
            "scheduled-guard <on|off>",
            "scheduled guard mode is on",
            "scheduled guard mode is off");
    };

    t["custom"] = [](const args& a) -> int {
        if (!need_args(a, 3, "custom <on|off>")) return 1;
        auto v = parse_onoff(a.at(2));
        if (!v) { xmz::log::error("usage: custom <on|off>"); return 1; }
        a1ctl::update_config("custom_priority_enabled", *v);
        xmz::log::info(*v ? "custom priority is on" : "custom priority is off");
        return 0;
    };

    t["add"]    = cmd::handle_add;
    t["remove"] = cmd::handle_remove;
    t["list"]   = cmd::handle_list;
    t["clear"]  = cmd::handle_clear;
    t["set"]    = cmd::handle_set;

    t["config"] = t["show-config"] = [](const args&) -> int {
        a1ctl::show_config();
        return 0;
    };

    t["set-interval"] = [](const args& a) -> int {
        if (!need_args(a, 3, "set-interval <seconds>")) return 1;
        auto v = parse_int(a.at(2));
        if (!v) { xmz::log::error("invalid seconds:", std::string(a.at(2))); return 1; }
        a1ctl::update_config_int("optimize_interval", *v);
        return 0;
    };

    t["loop-sleep"] = [](const args& a) -> int {
        if (!need_args(a, 3, "loop-sleep <seconds>")) return 1;
        auto v = parse_int(a.at(2));
        if (!v || *v < 1) {
            xmz::log::error("loop sleep time must be a positive integer");
            return 1;
        }
        a1ctl::update_config_int("loop_sleep_interval", *v);
        return 0;
    };

    t["auto-apply"] = [](const args& a) -> int {
        if (!need_args(a, 3, "auto-apply <on|off>")) return 1;
        auto v = parse_onoff(a.at(2));
        if (!v) { xmz::log::error("usage: auto-apply <on|off>"); return 1; }
        a1ctl::set_auto_apply(*v);
        return 0;
    };

    t["restore"] = t["restore-config"] = [](const args&) -> int {
        a1ctl::init_config();
        xmz::log::info("configuration restored from backup");
        return 0;
    };

    t["compat"] = t["compat-mode"] = [](const args& a) -> int {
        if (!need_args(a, 3, "compat <on|off>")) return 1;
        auto v = parse_onoff(a.at(2));
        if (!v) { xmz::log::error("usage: compat <on|off>"); return 1; }
        a1ctl::compat_mode(*v);
        return 0;
    };

    t["mod-switch"] = [](const args& a) -> int {
        if (!need_args(a, 3, "mod-switch <on|off>")) return 1;
        auto v = parse_onoff(a.at(2));
        if (!v) { xmz::log::error("usage: mod-switch <on|off>"); return 1; }
        a1ctl::mod_switch_mode(*v);
        return 0;
    };

    t["lock"] = [](const args& a) -> int {
        if (!need_args(a, 3, "lock <on|off>")) return 1;
        auto v = parse_onoff(a.at(2));
        if (!v) {
            xmz::log::error("please enter on/off, such as a1ctl lock on");
            return 1;
        }
        a1ctl::update_config("lock_use", *v);
        if (*v) {
            xmz::log::info("lock has been turned on");
            xmz::log::info("lock ensures the program is not affected by other processes while running,");
            xmz::log::info("avoiding accidents (e.g. config file corruption).");
            xmz::log::info("Drawback: only one process can run at a time.");
        } else {
            xmz::log::info("lock is closed");
            xmz::log::warn("lock has been turned off, A1 can now run in multi-threaded mode.");
            xmz::log::warn("however, this may cause data such as configuration files to be damaged.");
        }
        return 0;
    };

    t["help"]    = t["--help"] = t["-h"] = t["h"] = [](const args& a) -> int {
        xmz::println(help_text(std::string(a.at(0))));
        return 0;
    };

    t["version"] = [](const args&) -> int {
        xmz::println("A1Ctl Version:", a1::version::a1ctl);
        return 0;
    };

    t["-f"] = [](const args& a) -> int {
        if (a.has(2) && a.at(2) == "start") {
            a1ctl::start_a1_foreground();
            return 0;
        }
        xmz::log::error("command error: ", std::string(a.has(2) ? a.at(2) : ""));
        return 1;
    };

    return t;
}

int main(int argc, char *argv[]) {
    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1Ctl need set jb env value!");
        xmz::log::info("Use a1ctl status, not cxxa1ctl!");
        return 1;
    }

    a1::config::jb_path g_jb;
    a1::ini::ini_parser pini;

    if (argc < 2) {
        xmz::println(help_text(std::string(argv[0])));
        return 0;
    }

    a1ctl::init_config();

    bool lock_use = pini.get_bool("", "lock_use", true);
    if (lock_use) {
        std::string lock_file = g_jb.a1_dir + "/lock";
        g_lock_mgr.init(lock_file);
        g_lock_mgr.set_enabled(true);
        if (!g_lock_mgr.acquire()) return 1;
        signal(SIGINT,  signal_handler);
        signal(SIGTERM, signal_handler);
        atexit([]() { g_lock_mgr.release(); });
    }

    args a{argc, argv};
    auto table = build_commands();

    int rc = 0;
    auto it = table.find(a.at(1));
    if (it == table.end()) {
        if (a.at(1).empty()) {
            xmz::println(help_text(std::string(a.at(0))));
            rc = 0;
        } else {
            xmz::log::error("unknown command: ", std::string(a.at(1)));
            xmz::log::info("use 'a1ctl help' to view help");
            rc = 1;
        }
    } else {
        rc = it->second(a);
    }

    g_lock_mgr.release();
    return rc;
}
