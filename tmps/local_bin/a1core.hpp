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

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/get_sys_list.hpp>
#include <a1/core/config.hpp>
#include <src/bin/bundle_pid/bundle_pid.hpp>
#include <src/bin/bundle_pid/libproc.h>

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

    inline std::string get_process_name_by_pid(int pid) {
        char name[1024] = {0};
        int ret = proc_name(pid, name, sizeof(name));
        if (ret > 0) { return std::string(name); }
        return "";
    }

    // get process nice value
    inline void get_nice_by_pid() {
        errno = 0;
        int nice_val = getpriority(PRIO_PROCESS, pid);
        if (nice_val == -1 && errno != 0) { return 0; }
        return nice_val;
    }

    // get process CPU useage rate
    inline int get_cpu_by_pid(int pid, double interval = 0.5) {
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

    // by renice set priority
    inline bool set_priority_renice(pid_t pid, int priority) {
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

} /* namespace a1 */
