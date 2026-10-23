// set.hpp
#pragma once
#include <string>
#include <stdint.h>
#include <sys/resource.h>
#include <cerrno>
#include <unistd.h>
#include <sys/types.h>

#include <a1/core/a1/aux.hpp>

#include <src/bin/bundle/libproc.h>

namespace a1::set {
    // by renice set priority
    inline bool priority_renice(pid_t pid, int priority) {
        int orig_uid = getuid();
        // convert priority to nice value
        int renice_value = priority - 20;
        // restricted range
        if (renice_value < -20) renice_value = -20;
        if (renice_value > 19) renice_value = 19;
        // set the process priority
        if (!a1::is_root()) return false;
        if (setpriority(PRIO_PROCESS, pid, renice_value) == -1) {
            xmz::println("Failed to set priority for PID", pid, ":", strerror(errno));
            setuid(orig_uid);
            return false;
        }
        setuid(orig_uid);
        return true;
    }

    namespace _jetsam {
        // Jetsam的memorystatus_control API声明
        extern "C" int memorystatus_control(uint32_t command, pid_t pid, uint32_t flags, void *buffer, size_t buffersize);

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

        inline constexpr uint32_t MEMORYSTATUS_CMD_SET_PRIORITY = 1;
        inline constexpr uint32_t MEMORYSTATUS_CMD_GET_PRIORITY = 2;
        inline constexpr uint32_t MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT = 3;
        inline bool priority_jetsam_impl(pid_t pid, int32_t priority) {
        int orig_uid = getuid();
        if (!a1::is_root()) return false;
            int ret = memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY, pid, priority, nullptr, 0);
            if (ret == 0) {
                setuid(orig_uid);
                return true;
            } else {
                setuid(orig_uid);
                return false;
            }
        }
    } /* namespace _jetsam */

    inline bool priority_jetsamctl(pid_t pid, int32_t priority) { return _jetsam::priority_jetsam_impl(pid, priority); }
    // universal priority set
    inline bool priority(int pid, int priority) noexcept { return priority_renice(pid, priority) || priority_jetsamctl(pid, priority); }
} /* namespace a1::set */
