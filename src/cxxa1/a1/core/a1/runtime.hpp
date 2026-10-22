// runtime.hpp
#pragma once
#include <ctime>
#include <string>
#include <vector>
#include <unistd.h>
#include <regex>
#include <unordered_map>
#include <signal.h>

#include <a1/core/config.hpp>
#include <a1/core/a1/priority_manager.hpp>
#include <a1/core/a1/get.hpp>
#include <a1/core/a1adjust_process_auto.hpp>
#include <a1/core/a1/aux.hpp>

#include <src/bin/bundle/libproc.h>
#include <src/bin/bundle/bundle.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1 {
    inline void run_monitor(int interval = 15, const char *mode_name = "Scheduled Guard") {
        a1::config::jb_path g_jb;
        xmz::println(mode_name, " Working(interval:", interval, "s)");
        xmz::println("Monitoring processes periodically...");
        xmz::println("_______________________________________________");

        std::unordered_map<int, bool> processed_pids;
        std::unordered_map<std::string, int> priority_map;
        std::unordered_map<std::string, time_t> file_mtime;
        std::vector<std::string> EXCLUDED_PROCESSES = {
            "kernel_task", "launchd", "syslogd", "UserEventAgent",
            "configd", "CommCenter", "SpringBoard", "backboardd"
        };
        priority_manager pm;
        pm.read_priority_lists(true);
        int circulate = 0;
        while (true) {
            circulate++;
            xmz::log::info("Current number of cycles:", circulate);
            // Check lockstate
            if (check_lockstate()) {
                xmz::log::info("It is in the lock screen state and has been dormant");
                sleep(60);
                continue;
            }
            // Check config file changes
            if (check_config_changes(file_mtime)) {
                pm.read_priority_lists(true);
                priority_map.clear();
                // build priority map from high priority list
                for (const auto& p : pm.get_high_list()) priority_map[p] = HIGH_PRIORITY;
                // build priority map from low priority list
                for (const auto& p : pm.get_low_list()) priority_map[p] = LOW_PRIORITY;
                // add custom priorities
                for (const auto& [proc, prio] : pm.get_custom_list()) priority_map[proc] = prio;
            }
            // get process list (simulating ps output)
            auto processes = get_target_processes();
            // Clear dead PIDs
            int dead_pids = 0;
            for (auto it = processed_pids.begin(); it != processed_pids.end(); ) {
                if (kill(it->first, 0) != 0) {
                    it = processed_pids.erase(it);
                    dead_pids++;
                } else {
                    ++it;
                }
            }
            if (dead_pids > 0) {
               xmz::log::info("Cleared", dead_pids, "dead PIDs from tracking");
            }
            // process adjustments
            for (const auto& [process_name, target_priority] : priority_map) {
                if (process_name.empty()) continue;
                std::vector<int> pids_found;
                // try to find by bundle ID (if looks like xxx.xxx.xxx)
                if (std::regex_search(process_name, std::regex("^[a-zA-Z0-9_]+\\.[a-zA-Z0-9_]+\\.[a-zA-Z0-9_]+"))) {
                    // try bundle_pid first
                    int bundle_pid_result = a1::bin::bundle_pid(process_name.c_str());
                    if (bundle_pid_result != -1) {
                        pids_found.push_back(bundle_pid_result);
                        xmz::log::info("  Process:", process_name, "exists");
                    } else {
                        // fall back to searching in process list
                        for (const auto& [pid, name] : processes) {
                            if (name == process_name) {
                                pids_found.push_back(pid);
                                xmz::log::info("  Process:", process_name, "exists");
                            }
                        }
                    }
                } else {
                    // find by process name
                    for (const auto& [pid, name] : processes) {
                        if (name == process_name) {
                            pids_found.push_back(pid);
                            xmz::log::info("  Process:", name, "is", process_name);
                        }
                    }
                }
                for (int pid : pids_found) {
                    if (pid <= 0) continue;
                    if (processed_pids[pid]) continue;
                    // check if process should be excluded
                    bool excluded = false;
                    if (process_name != "SpringBoard") {
                        for (const auto& excl : EXCLUDED_PROCESSES) {
                            if (process_name == excl) {
                                excluded = true;
                                break;
                            }
                        }
                    }
                    if (excluded) continue;
                    // get current nice value
                    int current_nice = get::nice_by_pid(pid);
                    if (current_nice == -1) continue;
                    int target_nice = target_priority - 20;
                    if (current_nice == target_nice) continue;
                    // adjust the process
                    if (adjust_process_auto(pid, process_name.c_str(), std::to_string(target_priority).c_str()) == 0) {
                        processed_pids[pid] = true;
                        xmz::log::info("  PID:", pid, "priority value", current_nice, "->", target_nice);
                    }
                }
            }
            // control processed_pids size (limit to 200 as in original)
            if (processed_pids.size() > 200) {
                std::unordered_map<int, bool> new_processed_pids;
                int count = 0;
                for (const auto& [pid, _] : processed_pids) {
                    if (count >= 500) break;
                    new_processed_pids[pid] = true;
                    count++;
                }
                processed_pids = std::move(new_processed_pids);
            }
            sleep(interval);
        }
    }
} /* namespace a1 */
