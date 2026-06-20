#!/bin/bash

if [ -f '/etc/profile' ]; then
    source /etc/profile
elif [ -f '/var/jb/etc/profile' ]; then
    source /var/jb/etc/profile
else
    echo 'Where the fuck "profile"?' 1>&2
fi

if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    jb=""
fi

jb_a1="$jb/a1"

if [ -n "$jb_a1" ]; then
    if [ -f "$jb_a1/autofonf.ini" ]; then
        source "$jb_a1/autofonf.ini"
    elif [ -f "$jb_a1/a1_ADautoconf.sh" ]; then
        source "$jb_a1/a1_ADautoconf.sh"
        [ -f "$jb_a1/autofonf.ini" ] && source "$jb_a1/autofonf.ini"
    fi
fi


source "$jb_a1/config.conf"
source "$jb_a1/inside.ini"

JB_PREFIX="$jb"

# old
# if [ -d "/var/jb" ]; then
#     JB_PREFIX="/var/jb"
# else
#     JB_PREFIX=""
# fi

JETSAM_PRIORITY=20
MAX_CPU_PERCENT=15
EXCLUDED_PROCESSES=("SpringBoard" "backboardd" "CommCenter" "syslogd" "apsd" "configd" "launchd" "kernel" "syslog_relay")


get_target_processes() {
    local ex_list=$(IFS="|"; echo "${EXCLUDED_PROCESSES[*]}")
    ps -A -o pid,comm | awk -v exclusions="$ex_list" '
        BEGIN {
            split(exclusions, exclude, "|")
            for (i in exclude) excluded[exclude[i]] = 1
        }
        NR > 1 {
            if ($2 ~ /^kernel_/) next
            if ($2 in excluded) next
            print $1 "|" $2
        }
    '
}


set_priority_renice() {
    local pid=$1
    local priority=$2
    local renice_value=$((priority - 20))
    renice $renice_value -p $pid >/dev/null 2>&1
}


optimize_processes() {
    local target_processes=$(get_target_processes)
    
    if [[ -z "$target_processes" ]]; then
        return
    fi
    
    local count=0
    
    while IFS="|" read -r pid name; do
        if ! ps -p "$pid" >/dev/null 2>&1; then
            continue
        fi

        local cpu_usage=$(ps -p "$pid" -o %cpu 2>/dev/null | tail -n1 | awk '{print int($1+0.5)}' 2>/dev/null)
        
        if [[ -z "$cpu_usage" || ! "$cpu_usage" =~ ^[0-9]+$ ]]; then
            continue
        fi

        if [[ $cpu_usage -le $MAX_CPU_PERCENT ]]; then
            ${JB_PREFIX}/usr/bin/jetsamctl set priority "$pid" "$JETSAM_PRIORITY" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                ((count++))
            else
                set_priority_renice "$pid" "$JETSAM_PRIORITY"
                ((count++))
            fi
        fi
    done <<< "$target_processes"
    
    echo "Optimized $count processes"
}

load_modules() {
    source "$jb_a1/load_mod.sh"
    load_modules_common "a1-return"
}

main() {
    load_modules
    echo "returning..."
    optimize_processes
    echo "done"
}

main