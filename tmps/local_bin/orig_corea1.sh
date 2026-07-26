
# process tweak func
_a1_adjust_process_auto() {
    local pid=$1
    local process_name=$2
    local priority=$3
    
    [ -z "$pid" ] || [ -z "$process_name" ] && return 1
    if ! $ps -p "$pid" >/dev/null 2>&1; then
        return 1
    fi

    local renice_value=$((priority - 20))
    [ "$renice_value" -lt -20 ] && renice_value=-20
    [ "$renice_value" -gt 19 ] && renice_value=19

    if "$raise_power" "$jb/usr/bin/renice $renice_value -p $pid >/dev/null 2>&1"; then
        [ "$DEBUG_MODE" = "true" ] && echo "  [Auto] $process_name (PID:$pid) -> $priority"
        return 0
    fi
    
    if $jb/usr/bin/command -v jetsamctl >/dev/null 2>&1 && "$raise_power" "$jb/usr/bin/jetsamctl set priority $pid $priority >/dev/null 2>&1"; then
        [ "$DEBUG_MODE" = "true" ] && echo "  [Auto] $process_name (PID:$pid) -> $priority"
        return 0
    fi
    
    if [ -x "$jb/usr/bin/jetsamctl_" ] && "$raise_power $jb/usr/bin/jetsamctl_ -p $priority $pid >/dev/null 2>&1"; then
        [ "$DEBUG_MODE" = "true" ] && echo "  [Auto] $process_name (PID:$pid) -> $priority"
        return 0
    fi
    
    return 1
}

adjust_process_auto() { _a1_adjust_process_auto; }
# get target process list (用于动态优化)
_a1_get_target_processes() {
    local excluded_list="${1:-}"
    local exclude_pattern="SpringBoard|backboardd|CommCenter|syslogd|apsd|configd|launchd|kernel|syslog_relay"
    [ -n "$excluded_list" ] && exclude_pattern="$excluded_pattern|$excluded_list"
    $ps -A -o pid,comm 2>/dev/null | awk -v ex="$exclude_pattern" '
        NR > 1 {
            if ($2 ~ /^kernel_/) next
            if ($2 ~ ex) next
            print $1 "|" $2
        }
    '
}
# lockstate check
_a1_check_lockstate() {
    local notifyutil_path="$jb/usr/bin/notifyutil"
    if [ -x "$notifyutil_path" ]; then
        local lockstate=$("$notifyutil_path" -g com.apple.springboard.lockstate 2>/dev/null)
        if [[ "$lockstate" == *"1"* ]]; then
            return 0  # lockstate
        fi
    else
        if [ ! -f /tmp/.a1_notifyutil_warned ]; then
            echo "Warning: notifyutil not found, cannot detect lock state." >&2
            touch /tmp/.a1_notifyutil_warned
        fi
    fi
    return 1  # no lockstate
}
# config file Surveillance
_a1_check_config_changes() {
    local -n mtime_ref="$1"
    local reload_needed=0
    local conf_files=(
        "$jb_a1/high_priority.list"
        "$jb_a1/low_priority.list"
        "$jb_a1/custom_priority.list"
    )

    for f in "${conf_files[@]}"; do
        if [ -f "$f" ]; then
            local current_mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
            if [ "${mtime_ref[$f]}" != "$current_mtime" ]; then
                reload_needed=1
                mtime_ref["$f"]=$current_mtime
            fi
        fi
    done

    return $reload_needed
}
# Bundle ID Cache
_a1_get_bundle_id() {
    local app_path="$1"
    local bundle_id=""

    if [ -f "$app_path/Info.plist" ]; then
        bundle_id=$(plutil -key CFBundleIdentifier "$app_path/Info.plist" 2>/dev/null)
        [ -z "$bundle_id" ] && bundle_id="UNKNOWN"
    fi
    echo "$bundle_id"
}
# kern option tweak
_a1_apply_kernel_patches() {
    echo "Applying kernel patches..."
    echo "_______________________________"
    if [ -x "$jb/usr/sbin/sysctl" ]; then
        "$jb/usr/sbin/sysctl" kern.wq_max_threads=4096 2>/dev/null || true
        "$jb/usr/sbin/sysctl" kern.maxvnodes=100000 2>/dev/null || true
        "$jb/usr/sbin/sysctl" kern.memorystatus_sysprocs_idle_delay_time=0 2>/dev/null || true
        "$jb/usr/sbin/sysctl" kern.memorystatus_apps_idle_delay_time=0 2>/dev/null || true
    fi

    if [ -x "$jb/usr/bin/sysctl" ]; then
        "$jb/usr/bin/sysctl" kern.vm_page_free_min=10000 2>/dev/null || true
        "$jb/usr/bin/sysctl" kern.vm_page_free_reserved=256 2>/dev/null || true
        "$jb/usr/bin/sysctl" vm.swapusage 2>/dev/null || true
    fi

    echo "Done."
    echo "_______________________________________________"
}
# launchd process tweak
_a1_adjust_launchd() {
    local priority="${1:-$LAUNCHD_PRIORITY}"
    echo "Adjusting launchd priority..."
    
    if _a1_set_priority "1" "$priority"; then
        echo "    ✓ Set launchd priority to jetsam $priority"
    else
        echo "    ✗ Failed to adjust launchd priority"
    fi
    echo ""
}
# clean func
_a1_kill_pid() {
    local script_name="${1:-a1}"
    local count=0
    local pids=$($ps -eo pid,comm,args 2>/dev/null | grep -v grep | grep -E "(a1$|$script_name)" | awk '{print $1}')
    for pid in $pids; do
        if [ "$pid" -ne "$$" ] && [ "$pid" -ne "$PPID" ] && [ -n "$pid" ]; then
            echo "Kill $script_name process PID: $pid"
            kill -TERM "$pid" 2>/dev/null
            sleep 0.5
            ps -p "$pid" >/dev/null 2>&1 && kill -KILL "$pid" 2>/dev/null
            ((count++))
        fi
    done
    # clear zombie process
    $ps -eo pid,state,comm 2>/dev/null | grep -w Z | grep -w "$script_name" | awk '{print $1}' | xargs -r kill -9 2>/dev/null
    echo "Cleaned $count old processes"
}
# Core of monitoring mode
_a1_run_monitor() {
    local interval="${1:-15}"
    local mode_name="${2:-Scheduled Guard}"

    echo ""
    echo "$mode_name Working (interval: ${interval}s)"
    echo "Monitoring processes periodically..."
    echo "_______________________________________________"

    declare -A processed_pids
    declare -A priority_map
    declare -A file_mtime

    local check_interval="$interval"
    local ps_output_file="$jb_a1/.ps_cache.tmp"

    while true; do
        # lockstart check
        if _a1_check_lockstate; then
            sleep 60
            continue
        fi
        # check config file change
        if _a1_check_config_changes file_mtime; then
            read_priority_lists "true"
            priority_map=()
            local p
            for p in "${HIGH_PRIORITY_LIST[@]}"; do
                priority_map["$p"]=$HIGH_PRIORITY
            done
            for p in "${LOW_PRIORITY_LIST[@]}"; do
                priority_map["$p"]=$LOW_PRIORITY
            done
            if [ "$CUSTOM_PRIORITY_ENABLED" = "true" ] && [ -f "$jb_a1/custom_priority.list" ]; then
                while IFS='=' read -r proc prio; do
                    [ -z "$proc" ] && continue
                    [[ "$proc" =~ ^# ]] && continue
                    prio=$(echo "$prio" | tr -d '[:space:]')
                    [ -z "$prio" ] && prio=20
                    priority_map["$proc"]=$prio
                done < "$jb_a1/custom_priority.list"
            fi
        fi
        # get process list
        $ps -A -o pid=,comm=,nice=,args= 2>/dev/null | awk '
            {
                pid=$1; comm=$2; nice=$3;
                args=substr($0, index($0,$4));
                print pid "|" comm "|" nice "|" args
            }' > "$ps_output_file"
        # clear PID
        local pid
        for pid in "${!processed_pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                unset processed_pids["$pid"]
            fi
        done
        # Been through adjustments
        local process_name target_priority pids_found current_nice
        for process_name in "${!priority_map[@]}"; do
            [ -z "$process_name" ] && continue
            target_priority="${priority_map[$process_name]}"
            pids_found=""
            if [[ "$process_name" =~ ^[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+ ]]; then
                if [ -x "$jb/usr/bin/bundle_pid" ]; then
                    pids_found=$($jb/usr/bin/bundle_pid "$process_name" 2>/dev/null)
                fi
                if [ -z "$pids_found" ]; then
                    pids_found=$(awk -F'|' -v bid="$process_name" '$4 ~ bid {print $1}' "$ps_output_file" | sort -u | tr '\n' ' ')
                fi
            else
                pids_found=$(awk -F'|' -v p="$process_name" '$2 == p {print $1}' "$ps_output_file")
                if [ -z "$pids_found" ]; then
                    pids_found=$(awk -F'|' -v p="$process_name" '$4 ~ "[ /]"p"($| )" {print $1}' "$ps_output_file" | sort -u | tr '\n' ' ')
                fi
            fi
            for pid in $pids_found; do
                [ -z "$pid" ] || [ "$pid" -le 0 ] 2>/dev/null && continue
                [ "${processed_pids[$pid]}" = "1" ] && continue
                local excluded=0
                if [ "$process_name" != "SpringBoard" ]; then
                    for excl in "${EXCLUDED_PROCESSES[@]}"; do
                        if [ "$process_name" = "$excl" ]; then
                            excluded=1
                            break
                        fi
                    done
                fi
                [ $excluded -eq 1 ] && continue
                current_nice=$(awk -F'|' -v pid="$pid" '$1 == pid {print $3}' "$ps_output_file")
                [ -z "$current_nice" ] && continue
                local target_nice=$((target_priority - 20))
                if [ "$current_nice" -eq "$target_nice" ] 2>/dev/null; then
                    continue
                fi
                if adjust_process_auto "$pid" "$process_name" "$target_priority"; then
                    processed_pids["$pid"]=1
                fi
            done
        done
        rm -f "$ps_output_file"
        # Control processed_pids size
        if [ ${#processed_pids[@]} -gt 200 ]; then
            local count=0
            declare -A new_processed_pids
            for pid in "${!processed_pids[@]}"; do
                if [ $count -lt 500 ]; then
                    new_processed_pids["$pid"]=1
                    ((count++))
                else
                    break
                fi
            done
            processed_pids=()
            for pid in "${!new_processed_pids[@]}"; do
                processed_pids["$pid"]=1
            done
        fi
        sleep "$check_interval"
    done
}
# Compatible interface
# a1:scheduled_guard
scheduled_guard() { _a1_run_monitor 15 "Scheduled Guard"; }
# a1:auto_adjust
auto_adjust() { _a1_run_monitor 1 "Auto-Adjust"; }
# a1ctl:custom_auth_adjust, a1ctl:custom_scheduled_guard
_a1_start_monitor() {
    local interval="${1:-15}"
    local mode_name="${2:-Monitor}"
    if [ -n "$1" ] && [ "$1" -gt 0 ] 2>/dev/null; then
        mode_name="${mode_name} (interval: ${interval}s)"
    fi
    _a1_run_monitor "$interval" "$mode_name"
}
custom_auto_adjust() { _a1_start_monitor "${1:-1}" "Auto-Adjust"; }
custom_scheduled_guard() { _a1_start_monitor "${1:-15}" "Scheduled-Guard"; }
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
