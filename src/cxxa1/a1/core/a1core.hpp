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
#include <sys/types.h>
#include <signal.h>
#include <regex>
#include <notify.h>
#include <optional>
#include <sys/stat.h>
#include <unordered_map>
#include <sys/sysctl.h>
#include <sstream>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/get_sys_list.hpp>
#include <a1/core/config.hpp>
#include <src/bin/bundle/bundle_pid.hpp>
#include <src/bin/bundle/libproc.h>
#include <src/bin/bundle/bundle_pid.hpp>
#include <src/bin/bundle/pid_bundle.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>

namespace a1 {
    inline constexpr int HIGH_PRIORITY = 30;
    inline constexpr int LOW_PRIORITY = 10;
    inline constexpr int DEFAULT_PRIORITY = 20;
    // colors
    namespace colors {
        inline std::string red = "\033[0;31m";
        inline std::string green = "\033[0;32m";
        inline std::string yellow = "\033[1;33m";
        inline std::string blue = "\033[0;34m";
        inline std::string bright_yellow = "\033[93m";
        inline std::string bright_blue = "\033[94m";
        inline std::string nc = "\033[0m";
    } /* namespace color */

    // default system list
    inline void get_sys_high_list() { xmz::print(a1::coreapi::lists::high); }
    inline std::string get_sys_high_list_str() { return a1::coreapi::lists::high; }
    inline void get_system_low_list() { xmz::print(a1::coreapi::lists::low); }
    inline std::string get_sys_low_list_str() { return a1::coreapi::lists::low; }

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
    inline int find_pid_by_name(const char *target, pid_t& pid) {
        pid = a1::bin::bundle_pid(target);
        //xmz::println(pid);
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
        inline int nice_by_pid(pid_t pid) {
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
            int orig_uid = getuid();
            // convert priority to nice value
            int renice_value = priority - 20;
            // restricted range
            if (renice_value < -20) renice_value = -20;
            if (renice_value > 19) renice_value = 19;
            // set the process priority
            if (setuid(0) != 0) {
                xmz::log::error("setuid(0) failed!");
                return false;
            }
            if (setpriority(PRIO_PROCESS, pid, renice_value) == -1) {
                xmz::println("Failed to set priority for PID", pid, ":", strerror(errno));
                setuid(orig_uid);
                return false;
            }
            setuid(orig_uid);
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

            constexpr uint32_t MEMORYSTATUS_CMD_SET_PRIORITY = 1;
            constexpr uint32_t MEMORYSTATUS_CMD_GET_PRIORITY = 2;
            constexpr uint32_t MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT = 3;
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
            if (_jetsan::priority_jetsam_impl(pid, priority)) { return true; }
            return false;
        }

        // Universal priority set
        inline bool priority(int pid, int priority) noexcept {
            return priority_renice(pid, priority) || 
                   priority_jetsamctl(pid, priority);
        }
    } /* namespace set */

    // process tweak func
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

        if (proc_name.empty() && pid > 0) {
            const char* raw = a1::bin::pid_bundle(pid);
            if (raw != nullptr) {
                proc_name = raw;
                free((void*)raw);
            }
        }

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

        int orig_uid = getuid();
        if (setuid(0) != 0) {
            xmz::log::error("setuid(0) failed!");
            return 1;
        }
    
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

        setuid(orig_uid);
    
        return success ? 0 : 1;
    }

    inline int adjust_process_auto(int pid, const char *priority) {
        const char *process_name = nullptr;
        return adjust_process_auto_impl(pid, process_name, priority);
    }

    inline int adjust_process_auto(const char *process_name, const char *priority) {
        int pid = -1;
        return adjust_process_auto_impl(pid, process_name, priority);
    }

    inline int adjust_process_auto(int pid, const char *process_name, const char *priority) { return adjust_process_auto_impl(pid, process_name, priority); }

    // get target process list (used for dynamic optimization)
    inline std::vector<std::pair<int, std::string>> get_target_processes(const std::string& excluded_list = "") {
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
            if (*lockstate == 1) { return true; }
        } else {
            if (!xmz::aux::is_file("/tmp/.a1_notifyutil_warnd")) {
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

    // kern option tweak
    inline int apply_kernel_patches() {
        xmz::println("Applying kernel patches...");
        xmz::println("_______________________________");

        int orig_uid = getuid();
        if (setuid(0) != 0) { 
            xmz::log::error("setuid(0) failed!"); 
            return 1;
        }

        auto set_kern_sysctl = [](int mib1, int new_value) -> bool {
            int mib[2];
            mib[0] = CTL_KERN;
            mib[1] = mib1;
            size_t size = sizeof(new_value);
            if (sysctl(mib, 2, nullptr, nullptr, &new_value, size) == -1) {
                xmz::log::error("Failed to set kern.", mib1, ":", strerror(errno));
                return false;
            }
            return true;
        };

        #ifndef KERN_WQ_MAX_THREADS
        #define KERN_WQ_MAX_THREADS 0  // Adjust the value as needed
        #endif
        #ifndef KERN_MEMORYSTATUS_SYSPROCS_IDLE_DELAY_TIME
        #define KERN_MEMORYSTATUS_SYSPROCS_IDLE_DELAY_TIME 0  // Adjust the value as needed
        #endif
        #ifndef KERN_MEMORYSTATUS_APPS_IDLE_DELAY_TIME
        #define KERN_MEMORYSTATUS_APPS_IDLE_DELAY_TIME 0  // Adjust the value as needed
        #endif
        #ifndef VM_PAGE_FREE_MIN
        #define VM_PAGE_FREE_MIN 0  // Adjust the value as needed
        #endif
        #ifndef VM_PAGE_FREE_RESERVED
        #define VM_PAGE_FREE_RESERVED 0  // Adjust the value as needed
        #endif

        if (set_kern_sysctl(KERN_WQ_MAX_THREADS, 4096)) { xmz::log::info("Successfully set kern.wq_max_threads to 4096"); }
        if (set_kern_sysctl(KERN_MAXVNODES, 100000)) { xmz::log::info("Successfully set kern.maxvnodes to 100000"); }
        if (set_kern_sysctl(KERN_MEMORYSTATUS_SYSPROCS_IDLE_DELAY_TIME, 0)) { xmz::log::info("Successfully set kern.memorystatus_sysprocs_idle_delay_time to 0"); }
        if (set_kern_sysctl(KERN_MEMORYSTATUS_APPS_IDLE_DELAY_TIME, 0)) { xmz::log::info("Successfully set kern.memorystatus_apps_idle_delay_time to 0"); }

        auto set_vm_sysctl = [](int mib1, int new_value) -> bool {
            int mib[2];
            mib[0] = CTL_VM;
            mib[1] = mib1;
            size_t size = sizeof(new_value);
            if (sysctl(mib, 2, nullptr, nullptr, &new_value, size) == -1) {
                xmz::log::error("Failed to set vm.",mib1, ":", strerror(errno));
                return false;
            }
            return true;
        };

        if (set_vm_sysctl(VM_PAGE_FREE_MIN, 10000)) { xmz::log::info("Successfully set kern.vm_page_free_min to 10000"); }
        if (set_vm_sysctl(VM_PAGE_FREE_RESERVED, 256)) { xmz::log::info("Successfully set kern.vm_page_free_reserved to 256"); }

        auto get_vm_swapusage = []() {
            int mib[2];
            mib[0] = CTL_VM;
            mib[1] = VM_SWAPUSAGE;
            struct xsw_usage swap_usage;
            size_t swap_len = sizeof(swap_usage);
            if (sysctl(mib, 2, &swap_usage, &swap_len, nullptr, 0) == -1) {
                xmz::log::error("Failed to get vm.swapusage:", strerror(errno));
            } else {
                xmz::log::info("vm.swapusage: used=", swap_usage.xsu_used, "avail=", swap_usage.xsu_avail);
            }
        };
        get_vm_swapusage();

        setuid(orig_uid);

        xmz::println("Done.");
        xmz::println("_______________________________________________");
        return 0;
    }

    // launchd process tweak
    inline void adjust_launchd(int priority) {
        xmz::println("Adjusting launchd priority...");
        int launchd_pid = 1;
        if (set::priority(launchd_pid, priority)) {
            xmz::log::info("Set launchd priority to jetsam", priority);
        } else {
            xmz::log::error("Failed to adjust launchd priority");
        }
    }

    // clean func
    inline void kill_pid(const char *script_name = nullptr) {
        if (script_name == nullptr) {
            script_name = "a1";
        }
        int count = 0;

        auto get_a1_pid = [](const std::string& script_name) -> std::vector<int> {
            std::vector<int> pids;
            int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
            size_t size = 0;
            if (sysctl(mib, 4, nullptr, &size, nullptr, 0) < 0) { return pids; }
            std::vector<kinfo_proc> procs(size / sizeof(kinfo_proc));
            if (sysctl(mib, 4, procs.data(), &size, nullptr, 0) < 0) { return pids; }
            size_t count = size / sizeof(kinfo_proc);
            for (size_t i = 0; i < count; ++i) {
                int pid = procs[i].kp_proc.p_pid;
                if (pid <= 0) continue;
                std::string comm = procs[i].kp_proc.p_comm;
                if (pid == getpid()) continue;
                std::string cmdline;
                char buf[PROC_PIDPATHINFO_MAXSIZE] = {0};
                int ret = proc_pidpath(pid, buf, sizeof(buf));
                if (ret > 0) { cmdline = buf; }
                bool match_a1 = false;
                if (comm.size() >= 2) { match_a1 = (comm.substr(comm.size() - 2) == "a1"); }
                if (!match_a1 && !cmdline.empty()) {
                    size_t pos = cmdline.find_last_of('/');
                    std::string basename = (pos != std::string::npos) ? cmdline.substr(pos + 1) : cmdline;
                    match_a1 = (basename.size() >= 2 && basename.substr(basename.size() - 2) == "a1");
                }
                bool match_script = !script_name.empty() && 
                     (comm.find(script_name) != std::string::npos ||
                     cmdline.find(script_name) != std::string::npos);
                if (match_a1 || match_script) { pids.push_back(pid); }
            }
            return pids;
        };
        std::vector<int> pids = get_a1_pid(script_name);
        pid_t current_pid = getpid();
        pid_t parent_pid = getppid();

        for (int pid_int : pids) {
            pid_t pid = static_cast<pid_t>(pid_int);
            if (pid != current_pid && pid != parent_pid && pid > 0) {
                xmz::println("Kill", script_name, "process PID:", pid);
                kill(pid, SIGTERM);
                usleep(500000);
                int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
                struct kinfo_proc info;
                size_t info_size = sizeof(info);
                if (sysctl(mib, 4, &info, &info_size, nullptr, 0) == 0 && info.kp_proc.p_stat != 0) { kill(pid, SIGKILL); }
                count++;
            }
        }

        int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
        size_t size = 0;
        if (sysctl(mib, 4, nullptr, &size, nullptr, 0) == 0) {
            std::vector<kinfo_proc> procs(size / sizeof(kinfo_proc));
            if (sysctl(mib, 4, procs.data(), &size, nullptr, 0) == 0) {
                size_t proc_count = size / sizeof(kinfo_proc);
                for (size_t i = 0; i < proc_count; ++i) {
                    if (procs[i].kp_proc.p_stat == SZOMB) {
                        pid_t pid = procs[i].kp_proc.p_pid;
                        std::string comm = procs[i].kp_proc.p_comm;
                        if (comm.find(script_name) != std::string::npos) { kill(pid, SIGKILL); }
                    }
                }
            }
        }
        xmz::println("Cleaned", count, "old processes");
    }

    // Core of monitoring mode
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

        while (true) {
            // Check lockstate
            if (check_lockstate()) {
                sleep(60);
                continue;
            }

            // Check config file changes
            if (check_config_changes(file_mtime)) {
                pm.read_priority_lists(true);
                priority_map.clear();
                // build priority map from high priority list
                for (const auto& p : pm.get_high_list()) {
                    priority_map[p] = HIGH_PRIORITY;
                }
                // build priority map from low priority list
                for (const auto& p : pm.get_low_list()) {
                    priority_map[p] = LOW_PRIORITY;
                }
                // add custom priorities
                for (const auto& [proc, prio] : pm.get_custom_list()) {
                    priority_map[proc] = prio;
                }
            }
            // get process list (simulating ps output)
            auto processes = get_target_processes();
            // Clear dead PIDs
            for (auto it = processed_pids.begin(); it != processed_pids.end(); ) {
                if (kill(it->first, 0) != 0) {
                    it = processed_pids.erase(it);
                } else {
                    ++it;
                }
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
                    } else {
                        // fall back to searching in process list
                        for (const auto& [pid, name] : processes) {
                            if (name == process_name) {
                                pids_found.push_back(pid);
                            }
                        }
                    }
                } else {
                    // find by process name
                    for (const auto& [pid, name] : processes) {
                        if (name == process_name) {
                            pids_found.push_back(pid);
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

    // compatible interface
    inline void scheduled_guard() { return run_monitor(15, "Scheduled Guard"); }
    inline void auto_adjust() { run_monitor(1, "Auto-Adjust"); }
    // a1ctl:custom_auth_adjust, a1ctl:custom_scheduled_guard
    inline void start_monitor(int interval, const std::string& mode_name) {
        return run_monitor(interval, mode_name.c_str());
    }
    inline void custom_auto_adjust() { start_monitor(1, "Auto-Adjust"); }
    inline void custom_scheduled_guard() { start_monitor(15, "Scheduled-Guard"); }

} /* namespace a1 */
