// adjust_process_auto.hpp
#pragma once
#include <string>
#include <cstdlib>
#include <cerrno>
#include <signal.h>
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>
#include <unistd.h>
#include <a1/core/a1/set.hpp>
#include <src/bin/bundle/bundle.hpp>
#include <a1/core/a1cfg.hpp>

namespace a1 {
    inline int adjust_process_auto_impl(int pid, const char* process_name, const char* priority_str) {
        std::string proc_name;
        // process_name
        if (process_name == nullptr && pid <= 0) {
            xmz::log::error("adjust_process_auto_impl: need either pid or process_name");
            return 1;
        }
    
        if (process_name != nullptr) { proc_name = process_name; }

        if (pid <= 0 && !proc_name.empty()) {
            pid = a1::bin::bundle_pid(proc_name.c_str());
            if (pid <= 0) {
                xmz::log::error("Cannot find PID for process:", proc_name);
                return 1;
            }
        }

        if (proc_name.empty() && pid > 0) proc_name = a1::bin::pid_bundle(pid);

        if (priority_str == nullptr) {
            xmz::log::error("adjust_process_auto_impl: need priority!");
            return 1;
        }
    
        int priority = DEFAULT_PRIORITY;
        try {
            priority = std::stoi(priority_str);
        } catch (...) {
            xmz::log::error("Invalid priority value:", priority_str);
            return 1;
        }

        if (kill(pid, 0) == -1) {
            if (errno == ESRCH) {
                xmz::log::error("Process", pid, "does not exist");
                return 1;
            }
            xmz::log::error("Cannot access process", pid);
            return 1;
        }

        int renice_value = priority - 20;
        if (renice_value < -20) renice_value = -20;
        if (renice_value > 19) renice_value = 19;
    
        bool success = false;

        if (a1::set::priority_renice(pid, priority)) {
            xmz::log::info("[Auto]", proc_name, "(PID:", pid, ") ->", priority);
            success = true;
        } else {
            xmz::log::error("Failed to set renice for PID", pid);
        }

        if (!success && a1::set::priority_jetsamctl(pid, priority)) {
            xmz::log::info("[Auto]", proc_name, "(PID:", pid, ") -> jetsam", priority);
            success = true;
        } else if (!success) {
            xmz::log::error("Failed to set jetsam priority for PID", pid);
        }
    
        return success ? 0 : 1;
    }

    inline int adjust_process_auto(int pid, const char *priority) { return adjust_process_auto_impl(pid, nullptr, priority); }
    inline int adjust_process_auto(const char *process_name, const char *priority) { int pid = -1; return adjust_process_auto_impl(pid, process_name, priority); }
    inline int adjust_process_auto(int pid, const char *process_name, const char *priority) { return adjust_process_auto_impl(pid, process_name, priority); }
} /* namespace a1 */
