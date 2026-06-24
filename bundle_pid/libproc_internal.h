#ifndef _LIBPROC_INTERNALH_
#define _LIBPROC_INTERNALH_
#include <TargetConditionals.h>
#include <sys/cdefs.h>
#include <libproc.h>
#include <libproc_private.h>
#include <mach/message.h>
__BEGIN_DECLS
#define PROC_SETCPU_ACTION_NONE         0
#define PROC_SETCPU_ACTION_THROTTLE     1
int proc_setcpu_percentage(pid_t pid, int action, int percentage) __OSX_AVAILABLE_STARTING(__MAC_10_12_2, __IPHONE_5_0);
int proc_clear_cpulimits(pid_t pid) __OSX_AVAILABLE_STARTING(__MAC_10_12_2, __IPHONE_5_0);
int proc_setthread_cpupercent(uint8_t percentage, uint32_t ms_refill) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_5_0);
#if (TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR)
#define PROC_SETCPU_ACTION_SUSPEND      2
#define PROC_SETCPU_ACTION_TERMINATE    3
#define PROC_SETCPU_ACTION_NOTIFY       4
int proc_setcpu_deadline(pid_t pid, int action, uint64_t deadline) __OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_5_0);
int proc_setcpu_percentage_withdeadline(pid_t pid, int action, int percentage, uint64_t deadline) __OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_5_0);
#define PROC_APPSTATE_NONE              0
#define PROC_APPSTATE_ACTIVE            1
#define PROC_APPSTATE_BACKGROUND        2
#define PROC_APPSTATE_NONUI             3
#define PROC_APPSTATE_INACTIVE          4
int proc_setappstate(int pid, int appstate);
int proc_appstate(int pid, int * appstatep);
#define PROC_DEVSTATUS_SHORTTERM        1
#define PROC_DEVSTATUS_LONGTERM         2
int proc_devstatusnotify(int devicestatus);
#define PROC_PIDBIND_CLEAR      0
#define PROC_PIDBIND_SET        1
int proc_pidbind(int pid, uint64_t threadid, int bind);
int proc_can_use_foreground_hw(int pid, uint32_t *reason);
#else 
int proc_clear_vmpressure(pid_t pid);
int proc_set_owner_vmpressure(void);
int proc_set_delayidlesleep(void);
int proc_clear_delayidlesleep(void);
#define PROC_POLICY_OSX_APPTYPE_NONE            0
#define PROC_POLICY_OSX_APPTYPE_TAL             1       
#define PROC_POLICY_OSX_APPTYPE_WIDGET          2       
#define PROC_POLICY_OSX_APPTYPE_DASHCLIENT      2       
int proc_disable_apptype(pid_t pid, int apptype);
int proc_enable_apptype(pid_t pid, int apptype);
#endif 
int proc_donate_importance_boost(void);
int proc_importance_assertion_begin_with_msg(mach_msg_header_t  *msg,
    mach_msg_trailer_t *trailer,
    uint64_t *assertion_token) __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_8, __MAC_10_10, __IPHONE_6_0, __IPHONE_8_0);
int proc_importance_assertion_complete(uint64_t assertion_handle);
int proc_denap_assertion_begin_with_msg(mach_msg_header_t  *msg,
    uint64_t *assertion_token);
int proc_denap_assertion_complete(uint64_t assertion_handle);
int proc_set_cpumon_defaults(pid_t pid) __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int proc_set_cpumon_params(pid_t pid, int percentage, int interval) __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int proc_set_cpumon_params_fatal(pid_t pid, int percentage, int interval) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int proc_get_cpumon_params(pid_t pid, int *percentage, int *interval) __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int proc_resume_cpumon(pid_t pid) __OSX_AVAILABLE_STARTING(__MAC_10_12, __IPHONE_10_0);
int proc_disable_cpumon(pid_t pid) __OSX_AVAILABLE_STARTING(__MAC_10_8, __IPHONE_6_0);
int proc_set_wakemon_defaults(pid_t pid) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
int proc_set_wakemon_params(pid_t pid, int rate_hz, int flags) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
int proc_get_wakemon_params(pid_t pid, int *rate_hz, int *flags) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
int proc_disable_wakemon(pid_t pid) __OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0);
int proc_reset_footprint_interval(pid_t pid) __OSX_AVAILABLE_STARTING(__MAC_10_14, __IPHONE_12_0);
int proc_trace_log(pid_t pid, uint64_t uniqueid) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int proc_pidoriginatorinfo(int flavor, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);
int proc_listcoalitions(int flavor, int coaltype, void *buffer, int buffersize) __OSX_AVAILABLE_STARTING(__MAC_10_11, __IPHONE_8_3);
int proc_current_thread_schedinfo(void *buffer, size_t buffersize);
#if !TARGET_OS_SIMULATOR
#define PROC_SUPPRESS_SUCCESS                (0)
#define PROC_SUPPRESS_BAD_ARGUMENTS         (-1)
#define PROC_SUPPRESS_OLD_GENERATION        (-2)
#define PROC_SUPPRESS_ALREADY_SUPPRESSED    (-3)
int proc_suppress(pid_t pid, uint64_t *generation);
#endif 
int proc_set_dyld_all_image_info(void *buffer, int buffersize);
__END_DECLS
#endif 