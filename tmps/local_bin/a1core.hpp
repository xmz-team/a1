// a1core.hpp
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <sys/resource.h>
#include <cerrno>
#include <mach/mach_time.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <cunistd>
#include <sys/types.h>
#include <signal.h>
#include <regex>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/get_sys_list.hpp>
#include <a1/core/config.hpp>
#include <src/bin/bundle_pid/bundle_pid.hpp>
#include <src/bin/bundle_pid/libproc.h>
#include <src/bin/bundle/bundle_pid.hpp>
#include <src/bin/bundle/pid_bundld.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>

namespace a1 {
    // colors
    namespace colors {
        std::string red = "\033[0;31m";
        std::string green = "\033[0;32m";
        std::string yellow = "\033[1;33m";
        std::string blue = "\033[0;34m";
        std::string bright_yellow = "\033[93m";
        std::string bright_blue = "\033[94m";
        std::string nc = "\033[0m";
    } /* namespace color */

    // default system list
    inline void get_sys_high_list() { xmz::print(a1::coreapi::lists::high); }
    inline void get_system_low_list() { xmz::print(a1::coreapi::lists::low); }

    // priority list read
    class priority_manager {
    public:
        void read_priority_lists(bool filter = false) {
            a1::config::jb_path g_jb;
            // empty the previous data
            high_priority_list_.clear();
            low_priority_list_.clear();
            custom_priority_list_.clear();
            // list of parsing systems
            auto system_high = xmz::str::split(a1::coreapi::lists::high, "\n");
            auto system_low = xmz::str::split(a1::coreapi::lists::low, "\n");
            // remove the blank line
            auto remove_empty = [](std::vector<std::string>& vec) {
                vec.erase(std::remove_if(vec.begin(), vec.end(), 
                    [](const std::string& s) { return s.empty(); }), vec.end());
            };
            remove_empty(system_high);
            remove_empty(system_low);
            // read the high-priority list
            read_list_file(g_jb.a1_dir + "/high_priority.list", 
                       high_priority_list_, system_high, filter, true);
            // read the low-priority list
            read_list_file(g_jb.a1_dir + "/low_priority.list", 
                           low_priority_list_, system_low, filter, false);
            // read custom priority
            read_custom_list(g_jb.a1_dir + "/custom_priority.list");
        }
    
        const std::vector<std::string>& get_high_list() const { return high_priority_list_; }
        const std::vector<std::string>& get_low_list() const { return low_priority_list_; }
        const std::map<std::string, int>& get_custom_list() const { return custom_priority_list_; }

    private:
        std::vector<std::string> high_priority_list_;
        std::vector<std::string> low_priority_list_;
        std::map<std::string, int> custom_priority_list_;
        void read_list_file(const std::string& filepath, 
                            std::vector<std::string>& target_list,
                            const std::vector<std::string>& system_list,
                            bool filter, bool is_high_priority) {
            if (xmz::aux::is_file(filepath.c_str()) == 0) {  // file exist
                std::string content = xmz::fs::readfile_str(filepath);
                auto lines = xmz::str::split(content, "\n");
                for (const auto& line : lines) {
                    std::string trimmed = xmz::str::trim(line);
                    if (trimmed.empty() || trimmed[0] == '#') continue;
                    if (filter) {
                        // check whether it is in the system list
                        bool is_system = std::find(system_list.begin(), 
                                                  system_list.end(), 
                                                  trimmed) != system_list.end();
                        if (is_high_priority && trimmed == "SpringBoard") {
                            // SpringBoard always keeps
                            target_list.push_back(trimmed);
                        } else if (!is_system) {
                            // only non-system processes are added
                            target_list.push_back(trimmed);
                        }
                    } else {
                        target_list.push_back(trimmed);
                    }
                }
            } else {
                // the document does not exist
                if (!filter) {
                    target_list = system_list;  // use the system default list
                } else if (is_high_priority) {
                    target_list = {"SpringBoard"};  // the filter mode only retains SpringBoard
                }
            }
        }

        void read_custom_list(const std::string& filepath) {
            if (xmz::aux::exist(filepath.c_str()) != 0) return;
            std::string content = xmz::fs::readfile_str(filepath);
            auto lines = xmz::str::split(content, "\n");
            for (const auto& line : lines) {
                std::string trimmed = xmz::str::trim(line);
                if (trimmed.empty() || trimmed[0] == '#') continue;
                auto parts = xmz::str::split(trimmed, "=");
                if (parts.size() >= 2) {
                    std::string process_name = xmz::str::trim(parts[0]);
                    std::string priority_str = xmz::str::trim(parts[1]);
                    int priority = 20;  // default value
                    if (!priority_str.empty()) {
                        try {
                            priority = std::stoi(priority_str);
                        } catch (...) {
                            priority = 20;
                        }
                    }
                    custom_priority_list_[process_name] = priority;
                }
            }
        }
    };

    // by process find PID
    inline void find_pid_by_name(const char *target) {
        int pid = a1::bin::bundle_pid(target);
        xmz::println(pid);
        return pid == -1 ? 1 : 0;
    }

    namespace get {
        inline std::string process_name_by_pid(int pid) {
            char name[1024] = {0};
            int ret = proc_name(pid, name, sizeof(name));
            if (ret > 0) { return std::string(name); }
            return "";
        }

        // get process nice value
        inline void nice_by_pid() {
            errno = 0;
            int nice_val = getpriority(PRIO_PROCESS, pid);
            if (nice_val == -1 && errno != 0) { return 0; }
            return nice_val;
        }

        // get process CPU useage rate
        inline int cpu_by_pid(int pid, double interval = 0.5) {
            // the first sampling
            proc_taskinfo info1;
            if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info1, sizeof(info1)) <= 0) { return -1; }
            uint64_t time1 = info1.pti_total_user + info1.pti_total_system;
            // wait for a short time
            usleep(interval * 1000000);
            // the second sampling
            proc_taskinfo info2;
            if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info2, sizeof(info2)) <= 0) { return -1; }
            uint64_t time2 = info2.pti_total_user + info2.pti_total_system;
            // calculate the CPU utilization rate
            uint64_t delta = time2 - time1;
            // switch mach_absolute_time
            mach_timebase_info_data_t timebase;
            mach_timebase_info(&timebase);
            double elapsed_ns = (double)delta * timebase.numer / timebase.denom;
            double interval_ns = interval * 1e9;
            int percent = (int)(elapsed_ns / interval_ns * 100.0 + 0.5);
            return percent;
        }
    } /* namespace get */

    namespace set {
        // by renice set priority
        inline bool priority_renice(pid_t pid, int priority) {
            int orig_pid = std::getuid();
            // convert priority to nice value
            int renice_value = priority - 20;
            // restricted range
            if (renice_value < -20) renice_value = -20;
            if (renice_value > 19) renice_value = 19;
            // set the process priority
            std::setuid(0);
            if (setpriority(PRIO_PROCESS, pid, renice_value) == -1) {
                xmz::println("Failed to set priority for PID", pid, ":", strerror(erron));
                std::setuid(orig_uid);
                return false;
            }
            std::setuid(orig_uid);
            return true;
        }

        namespace _jetsan {
            extern "C" {
                int memorystatus_control(uint32_t command, pid_t pid, uint32_t flags, 
                                void *buffer, size_t buffersize);
            }
            enum JetsamPriority : int32_t {
                JETSAM_PRIORITY_IDLE                 = 0,
                JETSAM_PRIORITY_IDLE_DEFERRED        = 1,
                JETSAM_PRIORITY_AGING_BAND1          = 2,
                JETSAM_PRIORITY_AGING_BAND2          = 3,
                JETSAM_PRIORITY_AGING_BAND3          = 4,
                JETSAM_PRIORITY_AGING_BAND4          = 5,
                JETSAM_PRIORITY_AGING_BAND5          = 6,
                JETSAM_PRIORITY_BACKGROUND           = 10,
                JETSAM_PRIORITY_BACKGROUND_DEFERRED  = 11,
                JETSAM_PRIORITY_MAIL                 = 15,
                JETSAM_PRIORITY_PHONE                = 16,
                JETSAM_PRIORITY_UI_SUPPORT           = 17,
                JETSAM_PRIORITY_FOREGROUND           = 18,
                JETSAM_PRIORITY_FOREGROUND_DEFERRED  = 19,
                JETSAM_PRIORITY_FOREGROUND_SUPPORT   = 20,
                JETSAM_PRIORITY_CRITICAL             = 21
            };

            #define MEMORYSTATUS_CMD_SET_PRIORITY          1
            #define MEMORYSTATUS_CMD_GET_PRIORITY          2
            #define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 3
            inline bool priority_jetsam_impl(pid_t pid, int32_t priority) {
                int ret = memorystatus_control(
                    MEMORYSTATUS_CMD_SET_PRIORITY, 
                    pid, 
                    priority, 
                    nullptr, 
                    0
                );
                if (ret == 0) { return true; }
                return false;
            }
        } /* namespace _jetsam */

        inline bool priority_jetsamctl(pid_t pid, int32_t priority) {
            a1::config::jb_path g_jb;
            const char* jb = g_jb.jb.c_str();
            if (set_priority_jetsam_impl(pid, priority)) { return true; }
            return false;
        }

        // Universal priority set
        inline bool priority(int pid, int priority) noexcept {
            return set_priority_renice(pid, priority) || 
                   set_priority_jetsamctl(pid, priority);
        }
    } /* namespace set */

    // process tweak func
    inline int adjust_process_auto_impl(int pid, const char *process_name, const char *priority) {
        if (pid == 0) { pid = a1::bin::bundle_pid(process_name); }
        if (process_name == nullptr) {
            const char* raw = a1::bin::pid_bindle(pid);
            std::string process_name(raw ? raw : "");
free((void*)raw);
        }

        if (priority == nullptr) {
            xmz::log::error("adjust_procuess_auto_impl function need priority!");
            return 1;
        }

        if (kill(pid, 0) == -1) {
            if (errno == ESRCH) { return 1; }
            return 0;
        }
        return 0;

        int renice_value = priority - 20;
        renice_value = (renice_value < -20) ? -20 : renice_value;
        renice_value = (renice_value > 19) ? 19 : renice_value;

        int orig_uid = std::getuid();
        std::setuid(0);
        if (std::setuid(0) != 0) {
            xmz::log::error("setuid(0) failed!");
            return 1;
        }

        if (a1::set::priority_renice(pid, renice_value)) {
            xmz::log::info("[Auto]", process_name, "(PID:", "pid", ") ->", priority);
            return 0;
        } else {
            xmz::log::error("set renice value failed!");
            return 1;
        }

        if (a1::set:: priority_jetsamctl(pid, priority)) {
            xmz::log::info("[Auto]", process_name, "(PID:", pid, ") ->", priority);
            return 0
        } else {
            xmz::log::error("set jetsam value failed!");
        }
        return 1
    }

    inline int adjust_process_auto(int pid, const char *priority) {
        const char *process_name = nullptr;
        return adjust_process_auto_impl(pid, process_name, priority);
    }

    inline int adjust_process_auto(const char *process_name, const char *priority) {
        int pid = 0;
        return adjust_process_auto_impl(pid, process_name, priority);
    }

    inline int adjust_process_auto(int pid, const char *process_name, const char *priority) { return adjust_process_auto_impl(pid, process_name, priority); }

    std::vector<std::pair<int, std::string>> get_target_processes(const std::string& excluded_list = "") {
        std::vector<std::pair<int, std::string>> processes;
        // build exclusion pattern
        std::string exclude_pattern = "SpringBoard|backboardd|CommCenter|syslogd|apsd|configd|launchd|kernel|syslog_relay";
        std::string full_pattern = exclude_pattern;
        if (!excluded_list.empty()) {
            full_pattern = exclude_pattern + "|" + excluded_list;
        } else {
           xmz::log::warn("the excluded_list in the get_target_processes function has no value or is empty");
        }

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

} /* namespace a1 */
