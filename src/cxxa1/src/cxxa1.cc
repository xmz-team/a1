// main.cc
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <a1/core/a1core.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/config.hpp>
#include <a1/core/set_defaults.hpp>
#include <string>
#include <csignal>
#include <ctime>
#include <iostream>
#include <fstream>

#include <a1/core/version.hpp>

// wait for SpringBoard
void wait_for_springboard() {
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
int apply_custom_priority() {
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
void optimize_system() {
    auto& config = a1::coreapi::set_defaults_cfg();
    xmz::println("Optimizing system priorities...");
    wait_for_springboard();
    a1::priority_manager pm;
    pm.read_priority_lists(false);
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
void read_a1_config() {
    a1::coreapi::set_defaults();
    xmz::println("configuration reloaded from environment");
}

/* temporarily offline adjustment */
/*
# mod load
load_modules() {
    if [ -f "$jb_a1/load_mod.sh" ]; then
        source "$jb_a1/load_mod.sh"
        load_modules_common "a1" 2>/dev/null || true
    fi
}
*/

int main() {
    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1 need set jb env value!");
        xmz::log::info("Use a1 status, not cxxa1!");
        return 1;
    }
    a1::config::jb_path g_jb;
    time_t now = time(nullptr);
    xmz::println(std::ctime(&now));
    xmz::println("______________________");
    xmz::println("|A1 are working......|");
    xmz::println("|A1 Version:", a1::_coreapi::a1_version);
    xmz::println("----------------------");
    // Initialize environment, read defaults from environment
    a1::coreapi::set_defaults();
    auto& config = a1::coreapi::set_defaults_cfg();
    // read priority lists
    a1::priority_manager pm;
    pm.read_priority_lists(false);
    /*
    Load modules
    load_modules();
    */
    a1::apply_kernel_patches();
    a1::adjust_launchd(config.launchd_priority);
    optimize_system();
    // log reincarnation
    if (config.log_reincarnation) {
        std::string info_log = g_jb.a1_dir + "/a1.log";
        std::string err_log = g_jb.a1_dir + "/a1error.log";
        xmz::println("cleaning up...");
        std::ofstream info_file(info_log, std::ios::trunc);
        info_file.close();
        std::ofstream err_file(err_log, std::ios::trunc);
        err_file.close();
    }
/* temporarily offline adjustment
 *
    // experimental features
    if (config.experimental) {
        std::string exp_script = g_jb.a1_dir + "/a1_experimental.sh";
        if (xmz::aux::is_file(exp_script)) {
            xmz::println("Experimental function...");
            xmz::println("_______________________________");
            system(exp_script.c_str());
            xmz::println("Done.");
            xmz::println("_______________________________________________");
        }
    }
 */
    // mode selection
    if (config.auto_adjust) {
        xmz::println("starting Auto-Adjust (real-time) mode...");
        a1::auto_adjust();
    } else if (config.scheduled_guard) {
        xmz::println("starting Scheduled Guard mode...");
        a1::scheduled_guard();
    } else if (config.loop_mode) {
        xmz::println("starting Loop mode...");
        while (true) {
            // countdown display
            for (int i = config.loop_sleep_interval; i >= 1; i--) {
                xmz::print("\rNext Circulate Time:" + std::to_string(i) + "s");
                std::cout.flush();
                sleep(1);
            }
            xmz::println("");
            // reload config
            read_a1_config();
            // check if loop mode is still enabled
            if (!a1::coreapi::set_defaults_cfg().loop_mode) { break; }
            // re-read priority lists with filter
            pm.read_priority_lists(true);
            xmz::println("Running optimization cycle...");
            optimize_system();
        }
    } else {
        xmz::log::warn("No monitoring mode enabled.");
        return 0;
    }
    xmz::println("All operations completed successfully");
    sleep(1);
    return 0;
}
