// aux.hpp
#pragma once
#include <unistd.h>
#include <stdlib.h>
#include <unordered_map>
#include <optional>
#include <regex>
#include <vector>
#include <string>
#include <ctime>
#include <stdint.h>
#include <notify.h>
#include <src/bin/bundle/libproc.h>

#include <libxmz/log.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/fs.hpp>

namespace a1 {
    inline void init() {
        if (seteuid(0) != 0) { xmz::log::error("seteuid(0) failed, current euid:", geteuid()); }
        if (setuid(0) != 0) { xmz::log::error("setuid(0) failed, current uid:", getuid()); }
        if (getuid() != 0) {
            xmz::log::error("current uid:", getuid());
            return;
        }
    }

    inline bool is_root() {
        if (getuid() != 0 && setuid(0) != 0) {
            xmz::log::error("setuid(0) failed! uid is", getuid());
            xmz::log::error("euid is", geteuid());
            xmz::log::error("uid is", getuid());
            return false;
        }
        return true;
    }
    // get target process list (used for dynamic optimization)
    inline std::vector<std::pair<int, std::string>> get_target_processes(const std::string& excluded_list = "") {
        std::vector<std::pair<int, std::string>> processes;
        // build exclusion pattern
        std::string exclude_pattern = "SpringBoard|backboardd|CommCenter|syslogd|apsd|configd|launchd|kernel|syslog_relay";
        std::string full_pattern = exclude_pattern;
        full_pattern = exclude_pattern + "|" + excluded_list;
        std::regex pattern(full_pattern);
        // get number of processes
        int num_pids = proc_listpids(PROC_ALL_PIDS, 0, nullptr, 0);
        if (num_pids <= 0) return processes;
        // allocate buffer and get PIDs
        std::vector<int> pids(num_pids);
        num_pids = proc_listpids(PROC_ALL_PIDS, 0, pids.data(), num_pids * sizeof(int));
        if (num_pids <= 0) return processes;
        int count = num_pids / sizeof(int);
        for (int i = 0; i < count; i++) {
            int pid = pids[i];
            if (pid == 0) continue;
            // get process name
            char name[PROC_PIDPATHINFO_MAXSIZE] = {0};
            int ret = proc_name(pid, name, sizeof(name));
            if (ret > 0) {
                std::string comm(name);
                // skip kernel processes
                if (comm.find("kernel_") == 0) continue;
                // skip excluded processes
                if (std::regex_search(comm, pattern)) continue;
                processes.emplace_back(pid, comm);
            }
        }
        return processes;
    }
    // lockstate check
    inline bool check_lockstate() {
        auto lockstate = []() -> std::optional<uint64_t> {
            int token;
            if (notify_register_check("com.apple.springboard.lockstate", &token) != NOTIFY_STATUS_OK) { return std::nullopt; }
            uint64_t state;
            uint32_t status = notify_get_state(token, &state);
            notify_cancel(token);
            if (status != NOTIFY_STATUS_OK) { return std::nullopt; }
            return state;
        }();

        if (lockstate) {
            if (*lockstate == 1) return true;
        } else {
            if (!xmz::aux::is_file("/tmp/.a1_notifyutil_warned")) {
                xmz::log::warn("notifyutil not found, cannot detect lock state.");
                xmz::fs::touch("/tmp/.a1_notifyutil_warned");
            }
        }
        return false; // no lockstate
    }

    // config file Surveillance
    inline bool check_config_changes(std::unordered_map<std::string, time_t>& mtime_map) {
        a1::config::jb_path g_jb;
        bool reload_needed = false;
        std::vector<std::string> conf_files = {
            g_jb.a1_dir + "/high_priority.list",
            g_jb.a1_dir + "/low_priority.list",
            g_jb.a1_dir + "/custom_priority.list"
        };

        for (const auto& f : conf_files) {
            struct stat file_stat;
            time_t current_mtime = 0;
            if (stat(f.c_str(), &file_stat) == 0) { current_mtime = file_stat.st_mtime; }
            if (mtime_map[f] != current_mtime) {
                reload_needed = true;
                mtime_map[f] = current_mtime;
            }
        }
        return reload_needed;
    }
} /* namespace a1 */
