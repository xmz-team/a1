// a1core.hpp
#pragma once
#include <string>
#include <vector>
#include <tuple>
#include <unordered_map>
#include <optional>
#include <regex>
#include <cstdio>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <ctime>
#include <notify.h>
#include <src/bin/bundle/libproc.h>

#include <a1/core/config.hpp>
#include <a1/core/a1cfg.hpp>
#include <a1/core/get_sys_list.hpp>
#include <src/bin/bundle/bundle.hpp>
#include <a1/core/a1/all.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

namespace a1 {
    // default system list
    inline void get_sys_high_list() { xmz::print(a1::coreapi::lists::high); }
    inline std::string get_sys_high_list_str() { return a1::coreapi::lists::high; }
    inline void get_system_low_list() { xmz::print(a1::coreapi::lists::low); }
    inline std::string get_sys_low_list_str() { return a1::coreapi::lists::low; }

    // by process find PID
    inline int find_pid_by_name(const char *target) {
        pid_t pid = a1::bin::bundle_pid(target);
        return pid == -1 ? 0 : pid; /* return 0 by error, otherwise return PID */
    }

    inline int find_pid_by_name(const std::string& target) { return find_pid_by_name(target.c_str()); }

    // kern option tweak
    inline int apply_kernel_patches() {
        xmz::println("Applying kernel patches...");
        xmz::println("_______________________________");

        int orig_uid = getuid();
        if (!a1::is_root()) return 1;
        std::vector<std::tuple<std::string, int, std::string>> kern_params = {
            {"kern.wq_max_threads", 4096, "kern.wq_max_threads"},
            {"kern.maxvnodes", 100000, "kern.maxvnodes"},
            {"kern.memorystatus_sysprocs_idle_delay_time", 0, "kern.memorystatus_sysprocs_idle_delay_time"},
            {"kern.memorystatus_apps_idle_delay_time", 0, "kern.memorystatus_apps_idle_delay_time"}
        };
        for (const auto& [name, value, display] : kern_params) { a1::sys::get_and_set_kern_sysctl(name, value, display); }
        std::vector<std::tuple<std::string, int, std::string>> vm_params = {
            {"vm.vm_page_free_min", 10000, "vm.vm_page_free_min"},
            {"vm.vm_page_free_reserved", 256, "vm.vm_page_free_reserved"}
        };
        for (const auto& [name, value, display] : vm_params) { a1::sys::get_and_set_vm_sysctl(name, value, display); }
        a1::sys::get_vm_swapusage();
        setuid(orig_uid);

        xmz::println("Done.");
        xmz::println("_______________________________________________");
        return 0;
    }

    // launchd process tweak
    inline void adjust_launchd(int priority) {
        xmz::println("Adjusting launchd priority...");
        int launchd_pid = 1;
        if (set::priority(launchd_pid, priority)) xmz::log::info("Set launchd priority to jetsam", priority);
        else xmz::log::error("Failed to adjust launchd priority");
    }

    // compatible interface
    inline void scheduled_guard() { return run_monitor(15, "Scheduled Guard"); }
    inline void auto_adjust() { run_monitor(1, "Auto-Adjust"); }
    inline void start_monitor(int interval, const std::string& mode_name) { return run_monitor(interval, mode_name.c_str()); }
    inline void custom_auto_adjust() { start_monitor(1, "Auto-Adjust"); }
    inline void custom_scheduled_guard() { start_monitor(15, "Scheduled-Guard"); }

} /* namespace a1 */
