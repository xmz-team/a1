// a1ctlcore.hpp
#pragma once
#include <a1/core/myini.hpp>
#include <a1/core/set_defaults.hpp>
#include <a1/core/ctl/all.hpp>

#include <string>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
    inline void show_config() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_file(config_file)) {
            xmz::println("Current configuration");
            xmz::println("----------------");
            xmz::println(xmz::fs::readfile_str(config_file));
            xmz::println("----------------");
            pini.parse_file(config_file);
            xmz::println("priority setting:");
            xmz::println("  high priority:", pini.get_int("", "high_priority", a1::coreapi::get_cfg().high_priority));
            xmz::println("  low priority:", pini.get_int("", "low_priority", a1::coreapi::get_cfg().low_priority));
            xmz::println("  launchd priority:", pini.get_int("", "launchd_priority", a1::coreapi::get_cfg().launchd_priority));
            xmz::println("  jetsam priority:", pini.get_int("", "jetsam_priority", a1::coreapi::get_cfg().jetsam_priority));

            xmz::println("loop settings:");
            xmz::println("  loop sleep:", pini.get_int("", "loop_sleep_interval", a1::coreapi::get_cfg().loop_sleep_interval));

            xmz::println("other settings:");
            xmz::println("  take effect automatically:", pini.get_bool("", "auto_apply", a1::coreapi::get_cfg().auto_apply));
            xmz::println("  real-time automatic adjustment:", pini.get_bool("", "auto_adjust", a1::coreapi::get_cfg().auto_adjust));
            xmz::println("  regular guard:", pini.get_bool("", "scheduled_guard", a1::coreapi::get_cfg().scheduled_guard));

            xmz::println("  compatible mode:", pini.get_bool("", "compat_mode", a1::coreapi::get_cfg().compat_mode));
        } else {
            xmz::log::error("the document could not be found:", config_file);
            return;
        }
    }

    inline void list_priority(const std::string& opt) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        if (opt == "high" || opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f)) {
                xmz::println("high priority list");
                xmz::fs::readfile(g_jb.high_f);
            } else {
                xmz::log::error("the high priority list does not exist");
            }
        } else if (opt == "low" || opt == "l") {
            if (xmz::aux::is_file(g_jb.low_f)) {
                xmz::println("low priority list");
                xmz::fs::readfile(g_jb.low_f);
            } else {
                xmz::log::error("the low priority list does not exist");
            }
        } else if (opt == "custom" || opt == "c") {
            if (xmz::aux::is_file(g_jb.custom_f)) {
                xmz::println("custom priority list");
                xmz::fs::readfile(g_jb.custom_f);
            } else {
                xmz::log::error("the custom priority list does not exist.");
            }
        } else {
            xmz::log::error("undefined options:", opt);
            return;
        }
    }

    inline void clear_priority(const std::string& opt) {
        a1::config::jb_path g_jb;
        auto empty = [&](const std::string& name) -> void {
            if (name == "h" || name == "high") { xmz::fs::emptyfile(g_jb.high_f); } 
            else if (name == "l" || name == "low") { xmz::fs::emptyfile(g_jb.low_f); } 
            else if (name == "c" || name == "custom") { xmz::fs::emptyfile(g_jb.custom_f); }
            xmz::log::info("the", name, "priority list has been cleared");
            auto_apply_check();
        };
        if (opt == "high" || opt == "h") {
            empty("high");
        } else if (opt == "low" || opt == "l") {
            empty("low");
        } else if (opt == "custom" || opt == "c") {
            empty("custom");
            xmz::fs::writefile({"#custom priority format: process_name = value",
                                "#value range: 0-99 (Jetsam 0 = Nice -20, Jetsam 39 = Nice 19)",
                                "#example: com.apple.springboard = 0"}, g_jb.custom_f);
        } else {
            xmz::log::error("undefined options:", opt);
            return;
        }
    }
} /* namespace a1ctl */
