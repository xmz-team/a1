// sys.hpp
#pragma once
#include <string>
#include <vector>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h>
#include <sys/sysctl.h>

#include <src/bin/bundle/libproc.h>

#include <libxmz/io.hpp>

namespace a1 {
    inline void kill_pid(const char *script_name = nullptr) {
        if (script_name == nullptr) script_name = "cxxa1";
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
                if (ret > 0) cmdline = buf;
                bool match_a1 = false;
                if (comm.size() >= 2) match_a1 = (comm.substr(comm.size() - 2) == "cxxa1");
                if (!match_a1 && !cmdline.empty()) {
                    size_t pos = cmdline.find_last_of('/');
                    std::string basename = (pos != std::string::npos) ? cmdline.substr(pos + 1) : cmdline;
                    match_a1 = (basename.size() >= 2 && basename.substr(basename.size() - 2) == "cxxa1");
                }
                bool match_script = !script_name.empty() &&
                                    (comm.find(script_name) != std::string::npos ||
                                    cmdline.find(script_name) != std::string::npos);
                if (match_a1 || match_script) pids.push_back(pid);
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
                if (sysctl(mib, 4, &info, &info_size, nullptr, 0) == 0 && info.kp_proc.p_stat != 0) kill(pid, SIGKILL);
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
                        if (comm.find(script_name) != std::string::npos) kill(pid, SIGKILL);
                    }
                }
            }
        }
        if (count == 0) xmz::println("There is no old process to clean up");
        else xmz::println("Cleaned", count, "old processes");
    }
} /* namespace a1 */
