
# export function
# Most of the public functions
export -f _a1_colors
export -f _a1_echo
export -f _a1_cerr
export -f _a1_log
export -f _a1_set_defaults
export -f _a1_get_system_high_list
export -f _a1_get_system_low_list
export -f read_priority_lists
export -f _a1_find_pid_by_name
export -f _a1_get_process_name_by_pid
export -f _a1_get_nice_by_pid
export -f _a1_get_cpu_by_pid
export -f _a1_set_priority_renice
export -f _a1_set_priority_jetsamctl
export -f _a1_set_priority
export -f adjust_process_auto
export -f _a1_get_target_processes
export -f _a1_check_lockstate
export -f _a1_check_config_changes
export -f _a1_get_bundle_id
export -f _a1_apply_kernel_patches
export -f _a1_adjust_launchd
export -f _a1_kill_pid
export -f _a1_run_monitor
export -f scheduled_guard
export -f auto_adjust
export -f _a1_start_monitor
export -f custom_auto_adjust
export -f custom_scheduled_guard
# auth init env
# if source this file, auth init env
: '
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _a1_init_env
    _a1_colors
    _a1_set_defaults
    echo "A1 Core Library loaded successfully"
fi
'
