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

# 導入配置
source "$jb_a1/config.conf"
source "$jb_a1/inside.ini"

exec 3>>$jb_a1/a1.log
# 3 號輸出
out_3() {
    builtin echo "$@" >&3
}

# 輔助函數
cerr() {
    builtin printf "%s\n" >&2
}

# 初始化緩存變量
APP_CACHE_DATA=""

echo "$($jb/usr/bin/date)"
echo "__________________"
echo "|A1 are working..|"
echo "------------------"

A1PID=$($ps aux | $jb/usr/bin/grep "$jb/usr/local/bin/a1" | $jb/usr/bin/grep -v $jb/usr/bin/grep | $jb/usr/bin/awk '{print $2}')

echo "checking..."
while true; do
    if $ps aux | $jb/usr/bin/grep -q "[S]pringBoard"; then
        echo "check done."
        break
    fi
    echo "wait"
    read -t 3
done

JETSAM_PRIORITY=15
MAX_CPU_PERCENT=15
EXCLUDED_PROCESSES=("SpringBoard" "backboardd" "CommCenter" "syslogd" "apsd" "configd" "kernel" "syslog_relay")

HIGH_PRIORITY=0
LOW_PRIORITY=39

SYSTEM_HIGH_PRIORITY_LIST=(
    "SpringBoard" "backboardd" "syslogd" "configd" "AppleMediaServicesUI"
    "com.apple.WebKit.WebContent" "com.apple.WebKit.GPU" "com.apple.WebKit.Networking"
    "CommCenter" "TranslationUIService" "AccessibilityUIServer" "mobile_assertion_agent"
    "BTServer" "locationd" "mediaserverd"
)

SYSTEM_LOW_PRIORITY_LIST=(
    "cloudd" "itunesstored" "geod" "assistantd" "calaccessd" "apsd" "adid" "analyticsd"
    "nsurlsessiond" "softwareupdated" "ckdiscretionaryd" "itunescloudd" "com.apple.sbd"
    "cloudphotod" "searchd" "fseventsd" "delete_d" "assetsd" "imtransferagent"
    "pasteboardagent" "cloudpaird" "bird" "mstreamd" "weatherd" "nanoweatherprefsd"
    "watchlistd" "awdd" "triald" "rtcreportingd" "symptomsd" "symptomsd-diag"
    "metrickitd" "biomed" "coresymbolicationd" "revisiond" "adprivacyd" "aslmanager"
    "logd_helper" "siriinferenced" "parsec-fbf" "parsecd" "cloudphotod" "photoanalysisd"
    "mediaanalysisd" "searchpartyd" "appstored" "mobileassetd" "appleaccountd"
    "amsaccountsd" "amsengagementd" "bookassetd" "musiccache" "medialibraryd"
    "familycircled" "familynotificationd" "donotdisturbd" "wirelessproxd" "nehelper"
    "networkserviceproxy" "mapsupportd" "navd" "destinationd" "routined" "locationd_helper"
    "fitnesscoachingd" "healthrecordsd" "activityd" "achievementd" "gamectrld"
    "sociallayerd" "askpermissiond" "privacyaccountingd" "diagnosticextensionsd"
    "reportcrash" "spindump" "tailspind" "stackshot" "xpcproxy" "distnoted" "cfprefsd"
    "suggestd" "duetexpertd" "synceddefaultsd" "nanoprefsyncd" "nanosystemsettingsd"
    "nanotimekitcompaniond" "nanoregistryd" "nanoregistrylaunchd" "remoted"
    "remotemanagementd" "com.apple.MobileSoftwareUpdate.CleanupPreparePathService"
    "com.apple.StreamingUnzipService" "com.apple.SiriTTSService.TrialProxy"
    "com.apple.siri-distributed-evaluation" "com.apple.VideoSubscriberAccount.DeveloperService"
    "AppPredictionIntentsHelperService" "AssetCacheLocatorService" "DayStreamProcessorService"
    "EnforcementService" "HistoricalAnalyzerService" "IDSBlastDoorService"
    "IMDPersistenceAgent" "MTLCompilerService" "PerfPowerTelemetryClientRegistrationService"
    "TrustedPeersHelper" "ThreeBarsXPCService"
    "accountsd" "familycontrolsagent" "generatestorageagent" "icloudpairing"
    "keyboardservicesd" "mobileactivationd" "mobilebackup" "newsd" "notificationsd"
    "profiled" "screensharingd" "softwareupdate" "stocksd" "storeassetd"
    "storebookkeeperd" "storedownloadd" "streaming_zip_conduit" "touchsetupd" "useractivityd"
)

read_priority_lists() {
    local filter=$1
    HIGH_PRIORITY_LIST=()
    LOW_PRIORITY_LIST=()
    CUSTOM_PRIORITY_LIST=()
    
    if [ -f "$jb_a1/high_priority.list" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            [[ "$line" =~ ^# ]] && continue
            if [ "$filter" = "true" ]; then
                local is_system=0
                for system_proc in "${SYSTEM_HIGH_PRIORITY_LIST[@]}"; do
                    if [ "$line" = "$system_proc" ] && [ "$line" != "SpringBoard" ]; then
                        is_system=1
                        break
                    fi
                done
                [ $is_system -eq 0 ] || [ "$line" = "SpringBoard" ] && HIGH_PRIORITY_LIST+=("$line")
            else
                HIGH_PRIORITY_LIST+=("$line")
            fi
        done < "$jb_a1/high_priority.list"
    else
        if [ "$filter" = "true" ]; then
            HIGH_PRIORITY_LIST=("SpringBoard")
        else
            HIGH_PRIORITY_LIST=("${SYSTEM_HIGH_PRIORITY_LIST[@]}")
        fi
    fi
    
    if [ -f "$jb_a1/low_priority.list" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            [[ "$line" =~ ^# ]] && continue
            if [ "$filter" = "true" ]; then
                local is_system=0
                for system_proc in "${SYSTEM_LOW_PRIORITY_LIST[@]}"; do
                    [ "$line" = "$system_proc" ] && { is_system=1; break; }
                done
                [ $is_system -eq 0 ] && LOW_PRIORITY_LIST+=("$line")
            else
                LOW_PRIORITY_LIST+=("$line")
            fi
        done < "$jb_a1/low_priority.list"
    else
        [ "$filter" != "true" ] && LOW_PRIORITY_LIST=("${SYSTEM_LOW_PRIORITY_LIST[@]}")
    fi
    
    if [ -f "$jb_a1/custom_priority.list" ]; then
        while IFS='=' read -r process_name priority; do
            [ -z "$process_name" ] && continue
            [[ "$process_name" =~ ^# ]] && continue
            priority=$(echo "$priority" | $jb/usr/bin/tr -d '[:space:]')
            [ -z "$priority" ] && priority=20
            CUSTOM_PRIORITY_LIST+=("$process_name=$priority")
        done < "$jb_a1/custom_priority.list"
    fi
}

read_a1_config() {
    CONFIG_FILE="$jb_a1/config.conf"
    INSIDE_FILE="$jb_a1/inside.ini"

    if [ -f $CONFIG_FILE ]; then
        source "$CONFIG_FILE"
        source "$INSIDE_FILE"
    fi
}

apply_custom_priority() {
    [ "$CUSTOM_PRIORITY_ENABLED" != "true" ] && return 0
    
    local custom_file="$jb_a1/custom_priority.list"
    [ ! -f "$custom_file" ] && return 0
    
    echo "Applying custom priority settings..."
    echo ""
    
    local count=0
    
    for custom_entry in "${CUSTOM_PRIORITY_LIST[@]}"; do
        local process_name="${custom_entry%=*}"
        local priority="${custom_entry#*=}"
        
        [ -z "$process_name" ] || [ -z "$priority" ] && continue
        
        [ "$DEBUG_MODE" = "true" ] && echo "  Setting custom priority $priority for: $process_name"
        
        local PID=""
        if [[ "$process_name" =~ ^[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+ ]]; then
            [ -x "$jb/usr/bin/bundle_pid" ] && PID=$($jb/usr/bin/bundle_pid "$process_name" 2>/dev/null)
        else
            PID=$($ps -A -o pid=,comm= | $jb/usr/bin/awk -v p="$process_name" '$2 == p {print $1; exit}')
            [ -z "$PID" ] && PID=$($ps -A -o pid=,command= | $jb/usr/bin/grep -E "[ /]$process_name($| )" | $jb/usr/bin/awk '{print $1}' | $jb/usr/bin/head -1)
        fi
        
        if [ -n "$PID" ] && [ "$PID" -gt 0 ] 2>/dev/null; then
            [ "$DEBUG_MODE" = "true" ] && echo "    Process found: $process_name -> PID:$PID"
            
            local renice_value=$((priority - 20))
            [ "$renice_value" -lt -20 ] && renice_value=-20
            [ "$renice_value" -gt 19 ] && renice_value=19
            
            if set_priority_renice "$PID" "$priority"; then
                [ "$DEBUG_MODE" = "true" ] && echo "      ✓ Set custom priority via renice"
                ((count++))
            elif set_priority_jetsamctl "$PID" "$priority"; then
                [ "$DEBUG_MODE" = "true" ] && echo "      ✓ Set custom priority via jetsamctl"
                ((count++))
            else
                [ "$DEBUG_MODE" = "true" ] && echo "      ✗ Failed to set custom priority"
            fi
        else
            [ "$DEBUG_MODE" = "true" ] && echo "    Process not found: $process_name"
        fi
    done
    
    [ $count -gt 0 ] && echo "  Adjusted $count processes with custom priorities"
    echo ""
}

get_bundle_id_with_cache() {
    local app_path="$1"
    local bundle_id=""
    local app_name=$(basename "$app_path")
    
    if [[ "$APP_CACHE_DATA" == *"||$app_path::"* ]]; then
        local temp="${APP_CACHE_DATA#*||$app_path::}"
        bundle_id="${temp%%||*}"
        printf "$bundle_id"
        return
    fi

    if [ -f "$app_path/Info.plist" ]; then
        [ "$DEBUG_MODE" = "true" ] && echo -ne "\r\033[K  [Loading] Parsing: $(basename "$app_path")..." >&3

        bundle_id=$($jb/usr/bin/plutil -key CFBundleIdentifier "$app_path/Info.plist" 2>/dev/null)
        if [ -z "$bundle_id" ]; then
            bundle_id="UNKNOWN"
        fi

        APP_CACHE_DATA="${APP_CACHE_DATA}||$app_path::$bundle_id||"
        
        echo "$bundle_id"
    else
        echo ""
    fi
}

adjust_process_auto() {
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
    
    if $jb/usr/bin/renice $renice_value -p "$pid" >/dev/null 2>&1; then
        [ "$DEBUG_MODE" = "true" ] && echo "  [Auto] $process_name (PID:$pid) -> $priority"
        return 0
    fi
    
    if $jb/usr/bin/command -v jetsamctl >/dev/null 2>&1 && $jb/usr/bin/jetsamctl set priority "$pid" "$priority" >/dev/null 2>&1; then
        [ "$DEBUG_MODE" = "true" ] && echo "  [Auto] $process_name (PID:$pid) -> $priority"
        return 0
    fi
    
    if [ -x "$jb/usr/bin/jetsamctl_" ] && $jb/usr/bin/jetsamctl_ -p "$priority" "$pid" >/dev/null 2>&1; then
        [ "$DEBUG_MODE" = "true" ] && echo "  [Auto] $process_name (PID:$pid) -> $priority"
        return 0
    fi
    
    return 1
}

# ========================
# 定时守护模式 (每15秒扫描)
# ========================
scheduled_guard() {
    echo ""
    echo "Scheduled Guard Working (interval: 15s)"
    echo "Monitoring processes periodically..."
    echo "_______________________________________________"

    declare -A processed_pids
    declare -A priority_map
    declare -A file_mtime

    local check_interval=15
    local ps_output_file="$jb_a1/.ps_cache.tmp"
    local lockstate=""
    local notifyutil_path="$jb/usr/bin/notifyutil"

    while true; do
        # 锁屏检测
        if [ -x "$notifyutil_path" ]; then
            lockstate=$("$notifyutil_path" -g com.apple.springboard.lockstate 2>/dev/null)
            if [[ "$lockstate" == *"1"* ]]; then
                read -t 60
                continue
            fi
        else
            if [ ! -f /tmp/.a1_notifyutil_warned ]; then
                echo "Warning: notifyutil not found, cannot detect lock state. Continuing normal operation." >&2
                touch /tmp/.a1_notifyutil_warned
            fi
        fi

        # 检查配置文件变化
        local reload_needed=0
        local conf_files=(
            "$jb_a1/high_priority.list"
            "$jb_a1/low_priority.list"
            "$jb_a1/custom_priority.list"
        )
        for f in "${conf_files[@]}"; do
            if [ -f "$f" ]; then
                local current_mtime=$($jb/usr/bin/stat -c %Y "$f" 2>/dev/null || echo 0)
                if [ "${file_mtime[$f]}" != "$current_mtime" ]; then
                    reload_needed=1
                    file_mtime["$f"]=$current_mtime
                fi
            fi
        done

        if [ $reload_needed -eq 1 ]; then
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
                    prio=$(echo "$prio" | $jb/usr/bin/tr -d '[:space:]')
                    [ -z "$prio" ] && prio=20
                    priority_map["$proc"]=$prio
                done < "$jb_a1/custom_priority.list"
            fi
        fi

        # 获取进程列表
        $ps -A -o pid=,comm=,nice=,args= 2>/dev/null | awk '
            {
                pid=$1; comm=$2; nice=$3;
                args=substr($0, index($0,$4));
                print pid "|" comm "|" nice "|" args
            }' > "$ps_output_file"

        # 清理消失的 PID
        local pid
        for pid in "${!processed_pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                unset processed_pids["$pid"]
            fi
        done

        # 遍历调整
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

        # 控制 processed_pids 大小
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

        read -t $check_interval
    done
}

# ========================
# 实时自动调整模式 (1秒轮询)
# ========================
auto_adjust() {
    echo ""
    echo "Auto-Adjust Working (Real-time mode, interval: 1s)"
    echo "Monitoring processes with high frequency..."
    echo "_______________________________________________"

    declare -A processed_pids
    declare -A priority_map
    declare -A file_mtime

    local check_interval=1
    local ps_output_file="$jb_a1/.ps_cache.tmp"
    local lockstate=""
    local notifyutil_path="$jb/usr/bin/notifyutil"

    while true; do
        # 锁屏检测
        if [ -x "$notifyutil_path" ]; then
            lockstate=$("$notifyutil_path" -g com.apple.springboard.lockstate 2>/dev/null)
            if [[ "$lockstate" == *"1"* ]]; then
                read -t 60
                continue
            fi
        else
            if [ ! -f /tmp/.a1_notifyutil_warned ]; then
                echo "Warning: notifyutil not found, cannot detect lock state. Continuing normal operation." >&2
                touch /tmp/.a1_notifyutil_warned
            fi
        fi

        # 检查配置文件变化
        local reload_needed=0
        local conf_files=(
            "$jb_a1/high_priority.list"
            "$jb_a1/low_priority.list"
            "$jb_a1/custom_priority.list"
        )
        for f in "${conf_files[@]}"; do
            if [ -f "$f" ]; then
                local current_mtime=$($jb/usr/bin/stat -c %Y "$f" 2>/dev/null || echo 0)
                if [ "${file_mtime[$f]}" != "$current_mtime" ]; then
                    reload_needed=1
                    file_mtime["$f"]=$current_mtime
                fi
            fi
        done

        if [ $reload_needed -eq 1 ]; then
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
                    prio=$(echo "$prio" | $jb/usr/bin/tr -d '[:space:]')
                    [ -z "$prio" ] && prio=20
                    priority_map["$proc"]=$prio
                done < "$jb_a1/custom_priority.list"
            fi
        fi

        # 获取进程列表
        $ps -A -o pid=,comm=,nice=,args= 2>/dev/null | awk '
            {
                pid=$1; comm=$2; nice=$3;
                args=substr($0, index($0,$4));
                print pid "|" comm "|" nice "|" args
            }' > "$ps_output_file"

        # 清理消失的 PID
        local pid
        for pid in "${!processed_pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                unset processed_pids["$pid"]
            fi
        done

        # 遍历调整
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

        # 控制 processed_pids 大小
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

        sleep $check_interval
    done
}

set_priority_renice() {
    local pid=$1 priority=$2 renice_value=$((priority - 20))
    [ "$renice_value" -lt -20 ] && renice_value=-20
    [ "$renice_value" -gt 19 ] && renice_value=19
    $jb/usr/bin/renice $renice_value -p $pid >/dev/null 2>&1
    return $?
}

set_priority_jetsamctl() {
    local pid=$1 priority=$2
    if $jb/usr/bin/command -v jetsamctl >/dev/null 2>&1; then
        $jb/usr/bin/jetsamctl set priority "$pid" "$priority" >/dev/null 2>&1
        return $?
    fi
    [ -x "$jb/usr/bin/jetsamctl_" ] && $jb/usr/bin/jetsamctl_ -p "$priority" "$pid" >/dev/null 2>&1
    return $?
}

optimize_processes_dynamic() {
    [ "$DYNAMIC_OPTIMIZATION" != "true" ] && return
    
    local target_processes=$(get_target_processes)
    [ -z "$target_processes" ] && [ "$DEBUG_MODE" = "true" ] && echo "  No processes found for dynamic optimization" && return
    
    local count=0 processed=0 total=$($jb/usr/bin/echo "$target_processes" | wc -l | tr -d ' ')
    [ "$DEBUG_MODE" = "true" ] && echo "  Found $total candidate processes"
    
    while IFS="|" read -r pid name; do
        ((processed++))
        [ "$DEBUG_MODE" = "true" ] && printf "\r  Dynamic Processing: $processed/$total (PID:$pid $name)"
        
        $ps -p "$pid" >/dev/null 2>&1 || continue
        
        local cpu_usage=$($ps -p "$pid" -o %cpu 2>/dev/null | $jb/usr/bin/tail -n1 | $jb/usr/bin/awk '{print int($1+0.5)}' 2>/dev/null)
        [ -z "$cpu_usage" ] || ! [[ "$cpu_usage" =~ ^[0-9]+$ ]] && continue
        
        if [ $cpu_usage -le $MAX_CPU_PERCENT ]; then
            if set_priority_renice "$pid" "$JETSAM_PRIORITY"; then
                [ "$DEBUG_MODE" = "true" ] && echo "  Dynamic Optimized via renice: PID=$pid ($name)"
                ((count++))
            elif set_priority_jetsamctl "$pid" "$JETSAM_PRIORITY"; then
                [ "$DEBUG_MODE" = "true" ] && echo "  Dynamic Optimized via jetsamctl: PID=$pid ($name)"
                ((count++))
            fi
        fi
    done <<< "$target_processes"
    
    [ "$DEBUG_MODE" = "true" ] && echo -e "\n  Dynamic Optimization Complete: $count processes adjusted"
}

apply_priority_to_list() {
    local priority=$1 count=0; shift
    for process in "$@"; do
        echo "    Setting priority $priority for: $process"
        local PID="" SUCCESS=0
        
        if [[ "$process" =~ ^[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+ ]]; then
            [ -x "$jb/usr/bin/bundle_pid" ] && PID=$($jb/usr/bin/bundle_pid "$process" 2>/dev/null)
        else
            PID=$($ps -A -o pid=,comm= | $jb/usr/bin/awk -v p="$process" '$2 == p {print $1; exit}')
            [ -z "$PID" ] && PID=$($ps -A -o pid=,command= | $jb/usr/bin/grep -E "[ /]$process($| )" | $jb/usr/bin/awk '{print $1}' | $jb/usr/bin/head -1)
        fi
        
        if [ -n "$PID" ] && [ "$PID" -gt 0 ] 2>/dev/null; then
            echo "      Process found: $process -> PID:$PID"
            local renice_value=$((priority - 20))
            [ "$renice_value" -lt -20 ] && renice_value=-20
            [ "$renice_value" -gt 19 ] && renice_value=19
            
            if $jb/usr/bin/renice $renice_value -p "$PID" >/dev/null 2>&1; then
                echo "        ✓ Set via renice"
                ((count++))
                SUCCESS=1
            else
                if $jb/usr/bin/command -v jetsamctl &>/dev/null && $jb/usr/bin/jetsamctl -p "$priority" "$process" >/dev/null 2>&1; then
                    echo "        ✓ Set via jetsamctl"
                    ((count++))
                    SUCCESS=1
                elif [ $SUCCESS -eq 0 ] && [ -x "$jb/usr/bin/jetsamctl_" ] && $jb/usr/bin/jetsamctl_ -p "$priority" "$PID" >/dev/null 2>&1; then
                    echo "        ✓ Set via jetsamctl_"
                    ((count++))
                    SUCCESS=1
                else
                    [ "$DEBUG_MODE" = "true" ] && echo "        All methods failed for $process"
                fi
            fi
        else
            [ "$DEBUG_MODE" = "true" ] && echo "      Process not found: $process"
        fi
    done
    echo "  Adjusted $count processes to priority $priority"
}

apply_kernel_patches() {
    echo "Applying kernel patches..."
    echo "_______________________________"

    $jb/usr/sbin/sysctl kern.wq_max_threads=4096
    $jb/usr/sbin/sysctl kern.maxvnodes=100000
    $jb/usr/sbin/sysctl kern.memorystatus_sysprocs_idle_delay_time=0
    $jb/usr/sbin/sysctl kern.memorystatus_apps_idle_delay_time=0
    $jb/usr/bin/sysctl kern.vm_page_free_min=10000 2>/dev/null || true
    $jb/usr/bin/sysctl kern.vm_page_free_reserved=256 2>/dev/null || true

    $jb/usr/bin/sysctl vm.swapusage 2>/dev/null || true
    
    echo "Done."
    echo "_______________________________________________"
}

adjust_launchd_priority() {
    echo "Adjusting launchd priority..."
    local renice_value=$((LAUNCHD_PRIORITY - 20))
    [ "$renice_value" -lt -20 ] && renice_value=-20
    [ "$renice_value" -gt 19 ] && renice_value=19
    
    if $jb/usr/bin/renice $renice_value -p 1 >/dev/null 2>&1; then
        echo "    ✓ Set launchd priority to (renice $renice_value, jetsam $LAUNCHD_PRIORITY)"
    elif $jb/usr/bin/command -v jetsamctl >/dev/null 2>&1 && $jb/usr/bin/jetsamctl set priority "1" "$LAUNCHD_PRIORITY" >/dev/null 2>&1; then
        echo "    ✓ Set launchd priority via jetsamctl"
    elif [ -x "$jb/usr/bin/jetsamctl_" ] && $jb/usr/bin/jetsamctl_ -p "$LAUNCHD_PRIORITY" "1" >/dev/null 2>&1; then
        echo "    ✓ Set launchd priority via jetsamctl_"
    else
        echo "    ✗ Failed to adjust launchd priority"
    fi
    echo ""
}

optimize_system() {
    echo "Optimizing system priorities..."
    echo ""
    
    echo "Verifying SpringBoard status..."
    while true; do
        $ps aux | $jb/usr/bin/grep -q "[S]pringBoard" && break
        echo "SpringBoard not detected, waiting for SpringBoard to start..."
        read -t 3
    done
    echo "SpringBoard is running, proceeding with priority optimization..."
    
    [ "$DYNAMIC_OPTIMIZATION" = "true" ] && echo "Starting dynamic process optimization (jetsam priority: $JETSAM_PRIORITY)..." && optimize_processes_dynamic && echo ""
    
    # adjust_launchd_priority

    [ "$CUSTOM_PRIORITY_ENABLED" = "true" ] && apply_custom_priority
    
    echo "Boosting critical processes (jetsam priority: $HIGH_PRIORITY):"
    apply_priority_to_list $HIGH_PRIORITY "${HIGH_PRIORITY_LIST[@]}"
    echo ""
    
    [ ${#LOW_PRIORITY_LIST[@]} -gt 0 ] && echo "Lowering non-essential processes (jetsam priority: $LOW_PRIORITY):" && apply_priority_to_list $LOW_PRIORITY "${LOW_PRIORITY_LIST[@]}" && echo ""
    
    echo "_______________________________________________"
    echo ""
    echo "Optimization complete"
    echo "_______________________________________________"
}

optimize_system_loop() {
    [ "$DYNAMIC_OPTIMIZATION" = "true" ] && optimize_processes_dynamic
    
    local renice_value=$((LAUNCHD_PRIORITY - 20))
    [ "$renice_value" -lt -20 ] && renice_value=-20
    [ "$renice_value" -gt 19 ] && renice_value=19
    $jb/usr/bin/renice $renice_value -p 1 >/dev/null 2>&1 || {
        if $jb/usr/bin/command -v jetsamctl >/dev/null 2>&1; then
            $jb/usr/bin/jetsamctl set priority "1" "$LAUNCHD_PRIORITY" >/dev/null 2>&1 || {
                [ -x "$jb/usr/bin/jetsamctl_" ] && $jb/usr/bin/jetsamctl_ -p "$LAUNCHD_PRIORITY" "1" >/dev/null 2>&1
            }
        fi
    }
    
    for process in "${HIGH_PRIORITY_LIST[@]}"; do
        local PID=""
        if [[ "$process" =~ ^[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+ ]]; then
            [ -x "$jb/usr/bin/bundle_pid" ] && PID=$($jb/usr/bin/bundle_pid "$process" 2>/dev/null)
        else
            PID=$($ps -A -o pid=,comm= | $jb/usr/bin/awk -v p="$process" '$2 == p {print $1; exit}')
            [ -z "$PID" ] && PID=$($ps -A -o pid=,command= | $jb/usr/bin/grep -E "[ /]$process($| )" | $jb/usr/bin/awk '{print $1}' | $jb/usr/bin/head -1)
        fi
        
        [ -n "$PID" ] && [ "$PID" -gt 0 ] 2>/dev/null && {
            local renice_value=$((HIGH_PRIORITY - 20))
            [ "$renice_value" -lt -20 ] && renice_value=-20
            [ "$renice_value" -gt 19 ] && renice_value=19
            $jb/usr/bin/renice $renice_value -p "$PID" >/dev/null 2>&1 || {
                if $jb/usr/bin/command -v jetsamctl &>/dev/null; then
                    $jb/usr/bin/jetsamctl -p "$HIGH_PRIORITY" "$process" >/dev/null 2>&1 || {
                        [ -x "$jb/usr/bin/jetsamctl_" ] && $jb/usr/bin/jetsamctl_ -p "$HIGH_PRIORITY" "$PID" >/dev/null 2>&1
                    }
                fi
            }
        }
    done
    
    for process in "${LOW_PRIORITY_LIST[@]}"; do
        local PID=""
        if [[ "$process" =~ ^[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+ ]]; then
            [ -x "$jb/usr/bin/bundle_pid" ] && PID=$($jb/usr/bin/bundle_pid "$process" 2>/dev/null)
        else
            PID=$($ps -A -o pid=,comm= | $jb/usr/bin/awk -v p="$process" '$2 == p {print $1; exit}')
            [ -z "$PID" ] && PID=$($ps -A -o pid=,command= | $jb/usr/bin/grep -E "[ /]$process($| )" | $jb/usr/bin/awk '{print $1}' | $jb/usr/bin/head -1)
        fi
        
        [ -n "$PID" ] && [ "$PID" -gt 0 ] 2>/dev/null && {
            local renice_value=$((LOW_PRIORITY - 20))
            [ "$renice_value" -lt -20 ] && renice_value=-20
            [ "$renice_value" -gt 19 ] && renice_value=19
            $jb/usr/bin/renice $renice_value -p "$PID" >/dev/null 2>&1 || {
                if $jb/usr/bin/command -v jetsamctl &>/dev/null; then
                    $jb/usr/bin/jetsamctl -p "$LOW_PRIORITY" "$process" >/dev/null 2>&1 || {
                        [ -x "$jb/usr/bin/jetsamctl_" ] && $jb/usr/bin/jetsamctl_ -p "$LOW_PRIORITY" "$PID" >/dev/null 2>&1
                    }
                fi
            }
        }
    done
}

a1_kill_pid() {
    echo "cleaning a1..."
    local A1_PROCESSES=$($ps -eo pid,comm,args | $jb/usr/bin/grep -w "a1" | $jb/usr/bin/grep -v grep | $jb/usr/bin/awk '{print $1}')
    local A1_SCRIPT_PROCESSES=$($ps -eo pid,args | $jb/usr/bin/grep -F "$jb/usr/local/bin/a1" | $jb/usr/bin/grep -v grep | $jb/usr/bin/awk '{print $1}')
    local ALL_PIDS=$(echo "$A1_PROCESSES $A1_SCRIPT_PROCESSES" | tr ' ' '\n' | sort -nu)
    local count=0
    
    for PID in $ALL_PIDS; do
        [ "$PID" -ne "$$" ] && [ -n "$PID" ] && {
            echo "Kill a1 process PID: $PID"
            kill -TERM "$PID" 2>/dev/null
            read -t 0.5
            $ps -p "$PID" >/dev/null 2>&1 && kill -KILL "$PID" 2>/dev/null
            ((count++))
        }
    done
    
    echo "已 $count 个旧进程"
    $ps -eo pid,state,comm | $jb/usr/bin/grep -w Z | $jb/usr/bin/grep -w a1 | $jb/usr/bin/awk '{print $1}' | xargs -r kill -9 2>/dev/null
}

load_modules() {
    source "$jb_a1/load_mod.sh"
    load_modules_common "a1"
}

load_modules_from_a1() {
    load_modules
}

main() {
    RED='\033[0;31m'
    NC='\033[0m'
    BRIGHT_YELLOW='\033[93m'
    BRIGHT_BLUE='\033[94m'

    read_a1_config
    read_priority_lists "false"
    load_modules_from_a1
    apply_kernel_patches
    optimize_system

    [ "$LOG_REINCARNATION" = "true" ] && $jb_a1/a1_tee_log.sh

    if [ "$EXPERIMENTAL" = "true" ]; then
        a1_kill_pid
        if [ -f "$jb_a1/a1_experimental.sh" ]; then
            echo "Experimental function..."
            echo "_______________________________"
            "$jb_a1/a1_experimental.sh"
            echo "Done."
            echo "_______________________________________________"
        else
            echo "${RED}[Error]${NC}: ${BRIGHT_YELLOW}A1_experimental.sh does not exist!${NC}"
        fi
    fi

    # 模式选择（互斥）：
    # 1. AUTO_ADJUST="true"   -> 实时自动调整 (1秒轮询)
    # 2. SCHEDULED_GUARD="true" -> 定时守护 (15秒轮询)
    # 3. LOOP_MODE="true"     -> 原有的循环模式
    if [ "$AUTO_ADJUST" = "true" ]; then
        echo "Starting Auto-Adjust (real-time) mode..."
        read_priority_lists "true"
        auto_adjust
    elif [ "$SCHEDULED_GUARD" = "true" ]; then
        echo "Starting Scheduled Guard mode..."
        read_priority_lists "true"
        scheduled_guard
    elif [ "$LOOP_MODE" = "true" ]; then
        echo "Starting Loop mode..."
        while true; do
            for ((i=$LOOP_SLEEP_INTERVAL; i>=1; i--)); do
                printf "\rNext Circulate Time:%3ds" $i
                read -t 1 -n 1
            done
            read_a1_config
            [ "$LOOP_MODE" != "true" ] && break
            read_priority_lists "true"
            echo "Running optimization cycle..."
            optimize_system
        done
    else
        echo "Warn: No monitoring mode enabled. Please set AUTO_ADJUST=true, SCHEDULED_GUARD=true, or LOOP_MODE=true in config.conf" >&2
        echo "Because the monitoring mode is not turned on, the operation is completed."
        exit 0
    fi

    echo "All operations completed successfully"
    echo "done."
    read -t 1 -n 1
}

if [ "$use_sudo_a1" = "false" ]; then
    if [ -f $jb_a1/a1.log ] && [ -f $jb_a1/a1error.log ]; then
        main 2> >(sudo tee $jb_a1/a1error.log >&2) | sudo tee $jb_a1/a1.log
    else
        sudo touch $jb_a1/a1.log && sudo touch $jb_a1/a1error.log
        main 2> >(sudo tee $jb_a1/a1error.log >&2) | sudo tee $jb_a1/a1.log
    fi
else
    main 2> >(tee $jb_a1/a1error.log >&2) | tee $jb_a1/a1.log
fi
