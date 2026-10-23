// aux.hpp
#pragma once
#include <string>

#include <a1/core/config.hpp>
#include <a1/core/a1cfg.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/a1/kill_pid.hpp>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/log.hpp>
#include <libxmz/io.hpp>

namespace a1ctl {
    inline void default_config() {
        a1::config::jb_path g_jb;
        std::string cfg_f = g_jb.a1config + "/config.ini";
        xmz::fs::writefile(a1::coreapi::cfg_text, cfg_f);
    }

    inline void a1_conf() { return default_config(); }

    inline void init_config() {
        a1::config::jb_path g_jb;
        if (!xmz::aux::path_exist(g_jb.a1_dir)) xmz::fs::mkdir(g_jb.a1_dir);
        if (!xmz::aux::is_dir(g_jb.a1config)) xmz::fs::mkdir(g_jb.a1config);
        if (!xmz::aux::is_dir(g_jb.bak_d)) xmz::fs::mkdir(g_jb.bak_d);
        if (!xmz::aux::is_file(g_jb.high_f)) xmz::fs::writefile(a1::coreapi::lists::high, g_jb.high_f);
        if (!xmz::aux::is_file(g_jb.low_f)) xmz::fs::writefile(a1::coreapi::lists::low, g_jb.low_f);
        if (!xmz::aux::is_file(g_jb.custom_f)) {
            xmz::fs::writefile({"#custom priority format: process_name = value",
                                "#value range: 0-99 (Jetsam 0 = Nice -20, Jetsam 39 = Nice 19)",
                                "#example: com.apple.springboard = 0"}, g_jb.custom_f);
        }
    }

    inline void auto_apply_check() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;
        bool auto_apply = false;
        bool loop = false;
        bool auto_adjust = false;
        bool scheduled_guard = false;

        if (xmz::aux::is_file(config_file)) {
            pini.parse_file(config_file);
            auto_apply = pini.get_bool("", "auto_apply", false);
            loop = pini.get_bool("", "loop_mode", false);
            auto_adjust = pini.get_bool("", "auto_adjust", false);
            scheduled_guard = pini.get_bool("", "scheduled_guard", false);
        }

        if (auto_apply == true) {
            if (check_config_conflict() == 1) {
                xmz::log::error("configuration conflict, automatic application has stopped");
                return;
            } else {
                xmz::log::info("automatic application is taking effect...");
                a1::kill_pid();
                sleep(2);
            }
        }

        if (loop == true || auto_adjust == true || scheduled_guard == true) start_a1_service();
        else xmz::log::warn("A1 is not started");
    }

    inline int check_config_conflict() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (!xmz::aux::is_file(config_file)) {
            xmz::log::warn("file:", config_file, "not exist!");
            xmz::log::warn("The default configuration has been automatically created");
            xmz::fs::writefile(a1::coreapi::cfg_text, config_file);
        }

        if (!pini.parse_file(config_file)) return -1;
        bool loop_mode = pini.get_bool("", "loop_mode", false);
        bool auto_adjust = pini.get_bool("", "auto_adjust", false);
        bool scheduled_guard = pini.get_bool("", "scheduled_guard", false);
        int conflicts = 0;
        if (loop_mode == true && auto_adjust == true) {
            xmz::log::warn("loop_mode and auto_adjust cannot be turned on at the same time!");
            conflicts++;
        }

        if (loop_mode == true && scheduled_guard == true) {
            xmz::log::warn("loop_mode and scheduled_guard cannot be turned on at the same time!");
            conflicts++;
        }

        if (auto_adjust == true && scheduled_guard == true) {
            xmz::log::warn("auto_adjust and scheduled_guard cannot be turned on at the same time!");
            conflicts++;
        }

        if (conflicts != 0) {
            xmz::log::warn("It is recommended to adjust the configuration to prevent conflicts.");
            return 1;
        }

        return 0;
    }

    inline int check_a1_running() { if (a1::bin::bundle_pid("cxxa1") == -1) return 1; else return 0; }

    inline int check_if_should_run_a1() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;
        if (xmz::aux::is_file(config_file)) {
            pini.parse_file(config_file);
            pini.get_bool("", "loop_mode", false);
            pini.get_bool("", "auto_adjust", false);
            pini.get_bool("", "scheduled_guard", false);
            return 0;
        }
        return 1;
    }

    inline void check_status() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;
        if (xmz::aux::is_file(config_file)) {
            pini.parse_file(config_file);
            bool loop = pini.get_bool("", "loop_mode", false);
            bool custom_priority_enabled = pini.get_bool("", "custom_priority_enabled", false);
            bool auto_apply = pini.get_bool("", "auto_apply", false);
            bool auto_adjust = pini.get_bool("", "auto_adjust", false);
            bool scheduled_guard = pini.get_bool("", "scheduled_guard", false);
            bool module_switch = pini.get_bool("", "module_switch", false);

            bool compat_mode = pini.get_bool("", "compat_mode", false);
            bool lock_use = pini.get_bool("", "lock_use", false);

            auto auxoutcfg = [&](const std::string& name, bool configs = false) -> std::string {
                if (configs == false) {
                    std::string outcfg = name + " is turned off";
                    return outcfg;
                } else {
                    std::string outcfg = name + " is turned on";
                    return outcfg;
                }
            };
            if (check_a1_running() == 0) { xmz::println("A1 is running"); } else { xmz::println("A1 is not running"); }
            xmz::println("configuration status:");
            xmz::println("    ", auxoutcfg("loop_mode", loop));
            xmz::println("    ", auxoutcfg("auto_adjust", auto_adjust));
            xmz::println("    ", auxoutcfg("scheduled_guard", scheduled_guard));
            xmz::println("    ", auxoutcfg("auto_apply", auto_apply));
            xmz::println("    ", auxoutcfg("custom_priority_enabled", custom_priority_enabled));
            xmz::println("    ", auxoutcfg("module_switch", module_switch));
            xmz::println("    ", auxoutcfg("compat_mode", compat_mode));
            xmz::println("    ", auxoutcfg("lock_use", lock_use));
            check_config_conflict();
        } else {
            xmz::log::error("file:", config_file, "not exist");
            return;
        }
    }
} /* namespace a1ctl */
