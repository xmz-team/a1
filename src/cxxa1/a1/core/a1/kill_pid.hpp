// kill_pid.hpp
#pragma once
#include <string>
#include <vector>
#include <functional>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h>
#include <sys/sysctl.h>

#include <src/bin/bundle/libproc.h>

#include <libxmz/io.hpp>

namespace a1 {
    namespace _proc {
        struct info {
            pid_t pid;
            std::string comm;
            int stat;              // process status(SZOMB, etc.)
            std::string cmdline;   // full path of executable file
        };
    } /* namespace _proc */

    inline std::vector<_proc::info> list_all_procs() {
        std::vector<_proc::info> result;
        int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
        size_t size = 0;
        if (sysctl(mib, 4, nullptr, &size, nullptr, 0) < 0) return result;
        std::vector<kinfo_proc> procs(size / sizeof(kinfo_proc));
        if (sysctl(mib, 4, procs.data(), &size, nullptr, 0) < 0) return result;
        size_t count = size / sizeof(kinfo_proc);
        result.reserve(count);
        for (size_t i = 0; i < count; ++i) {
            _proc::info info;
            info.pid  = procs[i].kp_proc.p_pid;
            info.comm = procs[i].kp_proc.p_comm;
            info.stat = procs[i].kp_proc.p_stat;
            if (info.pid > 0) {
                char buf[PROC_PIDPATHINFO_MAXSIZE] = {0};
                if (proc_pidpath(info.pid, buf, sizeof(buf)) > 0) info.cmdline = buf;
            }
            result.push_back(std::move(info));
        }
        return result;
    }

    inline std::string get_pid_path(pid_t pid) {
        char buf[PROC_PIDPATHINFO_MAXSIZE] = {0};
        if (proc_pidpath(pid, buf, sizeof(buf)) > 0) return buf;
        return {};
    }

    // filter PID by predicate
    inline std::vector<pid_t> find_pids(const std::function<bool(const _proc::info&)>& pred,
                                        const std::vector<_proc::info>& procs) {
        std::vector<pid_t> pids;
        pid_t self = getpid(), parent = getppid();
        for (const auto& p : procs) {
            if (p.pid <= 0 || p.pid == self || p.pid == parent) continue;
            if (pred(p)) pids.push_back(p.pid);
        }
        return pids;
    }

    inline bool terminate_pid(pid_t pid, useconds_t grace_us = 500000) {
        if (pid <= 0) return false;
        kill(pid, SIGTERM);
        usleep(grace_us);
        int mib[] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
        struct kinfo_proc info;
        size_t info_size = sizeof(info);
        if (sysctl(mib, 4, &info, &info_size, nullptr, 0) == 0 && info.kp_proc.p_stat != 0) kill(pid, SIGKILL);
        return true;
    }

    // clean up the zombies with the specified name (substring matching)
    inline int reap_zombies(const std::string& name,
                            const std::vector<_proc::info>& procs) {
        int n = 0;
        for (const auto& p : procs) {
            if (p.stat == SZOMB && p.comm.find(name) != std::string::npos) {
                kill(p.pid, SIGKILL);
                ++n;
            }
        }
        return n;
    }

    inline void kill_pid(const char* script_name = nullptr) {
        if (script_name == nullptr) script_name = "cxxa1";
        const std::string name = script_name;
        auto procs = list_all_procs();
        auto matcher = [&](const _proc::info& p) -> bool {
            bool match_a1 = p.comm.size() >= 5 && p.comm.substr(p.comm.size() - 5) == "cxxa1";
            if (!match_a1 && !p.cmdline.empty()) {
                size_t pos = p.cmdline.find_last_of('/');
                std::string base = (pos != std::string::npos) ? p.cmdline.substr(pos + 1) : p.cmdline;
                match_a1 = base.size() >= 5 && base.substr(base.size() - 5) == "cxxa1";
            }
            bool match_script = p.comm.find(name) != std::string::npos || p.cmdline.find(name) != std::string::npos;
            return match_a1 || match_script;
        };

        auto pids = find_pids(matcher, procs);
        int count = 0;
        for (pid_t pid : pids) {
            xmz::println("Kill", name, "process PID:", pid);
            if (terminate_pid(pid)) ++count;
        }

        reap_zombies(name, procs);

        if (count == 0) xmz::println("There is no old process to clean up");
        else            xmz::println("Cleaned", count, "old processes");
    }
} /* namespace a1 */
