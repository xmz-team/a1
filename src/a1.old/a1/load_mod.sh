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
source "$jb_a1/lib/apis/log.sh"

get_a1_base_path() { echo "$jb_a1"; }
load_a1_configs() {
    local jb_a1="$1"
    if [ -n "$jb_a1" ]; then
        if [ -f "$jb_a1/autofonf.ini" ]; then
            source "$jb_a1/autofonf.ini"
        elif [ -f "$jb_a1/a1_ADautoconf.sh" ]; then
            source "$jb_a1/a1_ADautoconf.sh"
            [ -f "$jb_a1/autofonf.ini" ] && source "$jb_a1/autofonf.ini"
        fi
    fi
    if [ -n "$jb_a1" ]; then
        [ -f "$jb_a1/config.conf" ] && source "$jb_a1/config.conf"
        [ -f "$jb_a1/inside.ini" ] && source "$jb_a1/inside.ini"
    fi
}

get_current_script_type() {
    local script_name=$(basename "$0")
    local script_path="$0"
    case "$script_name" in
        "a1") echo "a1" ;;
        "a1ctl") echo "a1ctl" ;;
        "a1module"|"a1mod") echo "a1module" ;;
				"a1pm") echo "a1pm" ;;
        "a1-return") echo "a1-return" ;;
        *)
            if [[ "$script_path" == *"usr/local/bin/a1" ]]; then
                echo "a1"
            elif [[ "$script_path" == *"usr/local/bin/a1ctl" ]]; then
                echo "a1ctl"
            elif [[ "$script_path" == *"usr/local/bin/a1module" ]] || [[ "$script_path" == *"usr/local/bin/a1mod" ]]; then
                echo "a1module"
						elif [[ "$script_path" == *"usr/local/bin/a1om" ]]; then
								echo "a1pm"
            elif [[ "$script_path" == *"usr/local/bin/a1-return" ]]; then
                echo "a1-return"
            else
                if [ -n "$A1CTL_CALL_MOD" ] && [ "$A1CTL_CALL_MOD" = "true" ]; then
                    echo "a1ctl"
                elif [ -n "$_A1MODULE_MODE" ] && [ "$_A1MODULE_MODE" = "true" ]; then
                    echo "a1module"
                else
                    local pid=$$
                    local cmdline=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ' || ps -p $pid -o args= 2>/dev/null)
                    if [[ "$cmdline" == *"a1"* && "$cmdline" != *"a1ctl"* && "$cmdline" != *"a1module"* && "$cmdline" != *"a1pm"* ]]; then
                        echo "a1"
                    elif [[ "$cmdline" == *"a1ctl"* ]]; then
                        echo "a1ctl"
                    elif [[ "$cmdline" == *"a1module"* ]] || [[ "$cmdline" == *"a1mod"* ]]; then
                        echo "a1module"
										elif [[ "$cmdline" == *"a1pm"* ]]; then
                        echo "a1pm"
                    elif [[ "$cmdline" == *"a1-return"* ]]; then
                        echo "a1-return"
                    else
                        echo "unknown"
                    fi
                fi
            fi
            ;;
    esac
}

load_modules_common() {
    local script_type="${1:-$(get_current_script_type)}"
    ilog "加載模塊系統中..."
    local jb_a1=$(get_a1_base_path)
    load_a1_configs "$jb_a1"
    if [ "$a1_module_switch" != "true" ]; then
        ilog "模塊系統處於關閉狀態"
        return 0
    fi
    local MODULE_BASE="${a1_expand:-$jb_a1/expand}"
    local MODULE_DB="$MODULE_BASE/module.list.json"
    local ENABLED_DB="$MODULE_BASE/enabled.json"
    if [ ! -f "$ENABLED_DB" ] || [ ! -f "$MODULE_DB" ]; then
        wlog "模塊系統未初始化,已跳過模塊加載"
        return 0
    fi
    local enabled_modules=$(${jq:-jq} -r '.enabled_modules[]' "$ENABLED_DB" 2>/dev/null)
    if [ -z "$enabled_modules" ]; then
        wlog "沒有啟用/可用的模塊來加載"
        return 0
    fi
    local count=0
    while IFS= read -r module_id; do
        ilog "嘗試加載 $module_id 模塊中..."
        local module_info=$(${jq:-jq} -r \
            ".modules.official[\"$module_id\"] // 
             .modules.user[\"$module_id\"] // empty" \
            "$MODULE_DB" 2>/dev/null)
        if [ -z "$module_info" ]; then
            wlog "模塊 $module_id 不存在於數據庫"
            continue
        fi
        local target=$(echo "$module_info" | ${jq:-jq} -r '.target // "all"')
        local should_load=false
        case "$script_type" in
            "a1")
                if [[ "$target" == "a1" || "$target" == "all" ]]; then
                    should_load=true
                fi
                ;;
            "a1ctl")
                if [[ "$target" == "a1ctl" || "$target" == "all" ]]; then
                    should_load=true
                fi
                ;;
            "a1-return")
                if [[ "$target" == "a1-return" || "$target" == "all" ]]; then
                    should_load=true
                fi
                ;;
            "a1module")
                if [[ "$target" == "a1module" || "$target" == "all" ]]; then
                    should_load=true
                fi
                ;;
						"a1pm")
								if [[ "$target" == "a1pm" ]]; then
										should_load=true
								fi
								;;
            *)
                if [[ "$target" == "all" ]]; then
                    should_load=true
                fi
                ;;
        esac
        if [ "$should_load" = false ]; then
            wlog "模塊 $module_id 目標為 $target，不適用於 $script_type"
            continue
        fi
        local module_path=$(echo "$module_info" | ${jq:-jq} -r '.path // empty')
        local install_base=$(echo "$module_info" | ${jq:-jq} -r '.install_base // empty')
        local package=$(echo "$module_info" | ${jq:-jq} -r '.name // empty')
        # 優先使用 path 指定的主腳本
        if [ -n "$module_path" ] && [ -f "$module_path" ]; then
            source "$module_path"
            ((count++))
            ilog "已加載: $module_id"
        elif [ -n "$install_base" ] && [ -d "$install_base" ]; then
            local loaded=false
            local type_specific_scripts=(
                "$install_base/$script_type.sh"
                "$install_base/$script_type"
            )
            for script in "${type_specific_scripts[@]}"; do
                if [ -f "$script" ]; then
                    source "$script"
                    ((count++))
                    ilog "已加載: $module_id (來自 $script)"
                    loaded=true
                    break
                fi
            done
            if [ "$loaded" = false ]; then
                local generic_scripts=(
                    "$install_base/main.sh"
                    "$install_base/init.sh"
                    "$install_base/$module_id.sh"
                    "$install_base/$package.sh"
                )
                for script in "${generic_scripts[@]}"; do
                    if [ -f "$script" ]; then
                        source "$script"
                        ((count++))
                        ilog "已加載: $module_id (來自 $script)"
                        loaded=true
                        break
                    fi
                done
            fi
            if [ "$loaded" = false ]; then
                local first_sh=$(find "$install_base" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | head -1)
                if [ -n "$first_sh" ]; then
                    source "$first_sh"
                    ((count++))
                    ilog "已加載: $module_id (來自 $first_sh)"
                else
                    wlog "模塊文件不存在: $module_id"
                fi
            fi
        else
            wlog "模塊文件不存在/沒有: $module_id"
        fi
    done <<< "$enabled_modules"
    ilog "已加載 $count 個模塊"
    echo "_______________________________________________"
    return $count
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f get_a1_base_path
    export -f load_a1_configs
    export -f get_current_script_type
    export -f load_modules_common
fi

