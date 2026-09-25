// a1aux.hpp
#pragma once
#include <cstring>
#include <string>
#include <a1/core/a1core.hpp>
#include <a1/core/set_defaults.hpp>
#include <a1/core/mod/a1mod_luarun.hpp>
#include <libxmz/io.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/fs.hpp>

namespace a1::aux {
inline void load_modules(a1mod::luatime& lt);
// wait for SpringBoard
inline void wait_for_springboard() {
    xmz::println("checking SpringBoard...");
    while (true) {
        int sb_pid = a1::bin::bundle_pid("com.apple.springboard");
        if (sb_pid == -1) {
            sb_pid = a1::bin::bundle_pid("SpringBoard");
        }
        if (sb_pid != -1) {
            if (kill(sb_pid, 0) == 0) {
                xmz::println("SpringBoard ready.");
                break;
            }
        }
        xmz::println("waiting for SpringBoard...");
        sleep(3);
    }
}
// apply custom priority settings
inline int apply_custom_priority() {
    auto& config = a1::coreapi::set_defaults_cfg();
    a1::config::jb_path g_jb;
    if (!config.custom_priority_enabled) { return 0; }
    std::string custom_file = g_jb.a1_dir + "/custom_priority.list";
    if (xmz::aux::is_file(custom_file.c_str())) { return 0; }
    xmz::println("Applying custom priority settings...");
    a1::ini::ini_parser parser;
    if (!parser.parse_file(custom_file)) {
        xmz::perrln("  Failed to parse custom priority file");
        return 0;
    }
    int count = 0;
    auto process_names = parser.get_key("");
    for (const auto& process_name : process_names) {
        int priority = parser.get_int("", process_name, 20);
        pid_t pid = -1;
        a1::find_pid_by_name(process_name.c_str(), pid);
        if (pid > 0) {
            if (a1::set::priority(pid, priority)) {
                if (config.debug_mode) {
                    xmz::println("  " + process_name + " -> " + std::to_string(priority));
                }
                count++;
            }
        }
    }
    if (count > 0) {
        xmz::println("Adjusted " + std::to_string(count) + " processes with custom priorities");
    }
    return count;
}
// main optimization logic
inline void optimize_system() {
    auto& config = a1::coreapi::set_defaults_cfg();
    xmz::println("Optimizing system priorities...");
    wait_for_springboard();
    a1::priority_manager pm;
    pm.read_priority_lists(true);
    // apply high priority list
    const auto& high_list = pm.get_high_list();
    if (!high_list.empty()) {
        xmz::println("Boosting critical processes (jetsam priority: " + 
                     std::to_string(config.high_priority) + "):");
        xmz::println("If it fails, please try to re-execute it with sudo a1");
        int count = 0;
        for (const auto& process : high_list) {
            pid_t pid = -1;
            a1::find_pid_by_name(process.c_str(), pid);
            if (pid > 0) {
                if (a1::set::priority(pid, config.high_priority)) {
                    if (config.debug_mode) {
                        xmz::println("  " + process + " (PID:" + 
                                    std::to_string(pid) + ") -> " + 
                                    std::to_string(config.high_priority));
                    }
                    count++;
                }
            } else {
                if (config.debug_mode) {
                    xmz::println("  " + process + " not found");
                }
            }
        }
        xmz::println("  Adjusted " + std::to_string(count) + 
                    " processes to priority " + std::to_string(config.high_priority));
        xmz::println("");
    } else {
        xmz::log::warn("No high priority processes defined");
        xmz::println("");
    }
    // apply low priority list
    const auto& low_list = pm.get_low_list();
    if (!low_list.empty()) {
        xmz::println("Lowering non-essential processes (jetsam priority: " + 
                     std::to_string(config.low_priority) + "):");
        int count = 0;
        for (const auto& process : low_list) {
            pid_t pid = -1;
            a1::find_pid_by_name(process.c_str(), pid);
            if (pid > 0) {
                if (a1::set::priority(pid, config.low_priority)) {
                    if (config.debug_mode) {
                        xmz::println("  " + process + " (PID:" + 
                                    std::to_string(pid) + ") -> " + 
                                    std::to_string(config.low_priority));
                    }
                    count++;
                }
            } else {
                if (config.debug_mode) {
                    xmz::println("  " + process + " not found");
                }
            }
        }
        xmz::println("  Adjusted " + std::to_string(count) + 
                    " processes to priority " + std::to_string(config.low_priority));
        xmz::println("");
    } else {
        xmz::log::warn("No low priority processes defined");
        xmz::println("");
    }
    // apply custom priority
    apply_custom_priority();
    xmz::println("_______________________________________________");
    xmz::println("Optimization complete");
    xmz::println("_______________________________________________");
}
// reload configuration
inline void read_a1_config() {
    a1::coreapi::set_defaults();
    xmz::println("configuration reloaded from environment");
}
} /* namespace a1::aux */
