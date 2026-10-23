// get.hpp
#pragma once
#include <string>
#include <stdint.h>
#include <sys/resource.h>
#include <cerrno>
#include <mach/mach_time.h>
#include <unistd.h>
#include <sys/types.h>

#include <src/bin/bundle/libproc.h>

namespace a1::get {
    inline std::string process_name_by_pid(int pid) {
        char name[1024] = {0};
        int ret = proc_name(pid, name, sizeof(name));
        if (ret > 0) return std::string(name);
        return "";
    }

    // get process nice value
    inline int nice_by_pid(pid_t pid) {
        errno = 0;
        int nice_val = getpriority(PRIO_PROCESS, pid);
        if (nice_val == -1 && errno != 0) return 0;
        return nice_val;
    }

    // get process CPU useage rate
    inline int cpu_by_pid(int pid, double interval = 0.5) {
        // the first sampling
        proc_taskinfo info1;
        if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info1, sizeof(info1)) <= 0) return -1;
        uint64_t time1 = info1.pti_total_user + info1.pti_total_system;
        // wait for a short time
        usleep(interval * 1000000);
        // the second sampling
        proc_taskinfo info2;
        if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info2, sizeof(info2)) <= 0) return -1;
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
} /* namespace a1::get */
