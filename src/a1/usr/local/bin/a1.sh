#!/bin/bash

if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    jb=""
fi

jb_a1="$jb/a1"
# 加载配置
if [ -n "$jb_a1" ]; then
    if [ -f "$jb_a1/autofonf.ini" ]; then
        source "$jb_a1/autofonf.ini"
    elif [ -f "$jb_a1/a1_ADautoconf.sh" ]; then
        source "$jb_a1/a1_ADautoconf.sh"
        [ -f "$jb_a1/autofonf.ini" ] && source "$jb_a1/autofonf.ini"
    fi
fi
# 导入配置和核心
source "$jb_a1/lib/core.sh"
source "$jb_a1/config.conf"
source "$jb_a1/inside.ini"
# 日志重定向
exec 3>>$jb_a1/a1.log
out_3() { builtin echo "$@" >&3; }
cerr() { builtin printf "%b\n" "$@" >&2; }
# 模块加载
load_modules() {
    if [ -f "$jb_a1/load_mod.sh" ]; then
        source "$jb_a1/load_mod.sh"
        load_modules_common "a1" 2>/dev/null || true
    fi
}
# 等待 SpringBoard
wait_for_springboard() {
    echo "Checking SpringBoard..."
    while true; do
        if $ps aux | grep -q "[S]pringBoard"; then
            echo "SpringBoard ready."
            break
        fi
        echo "Waiting for SpringBoard..."
        sleep 3
    done
}
# 应用自定义优先级
apply_custom_priority() {
    [ "$CUSTOM_PRIORITY_ENABLED" != "true" ] && return 0
    local custom_file="$jb_a1/custom_priority.list"
    [ ! -f "$custom_file" ] && return 0
    echo "Applying custom priority settings..."
    local count=0
    while IFS='=' read -r process_name priority; do
        [ -z "$process_name" ] && continue
        [[ "$process_name" =~ ^# ]] && continue
        priority=$(echo "$priority" | tr -d '[:space:]')
        [ -z "$priority" ] && priority=20
        local pid=$(_a1_find_pid_by_name "$process_name")
        if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
            if _a1_set_priority "$pid" "$priority"; then
                [ "$DEBUG_MODE" = "true" ] && echo "  ✓ $process_name -> $priority"
                ((count++))
            fi
        fi
    done < "$custom_file"
    [ $count -gt 0 ] && echo "  Adjusted $count processes with custom priorities"
    echo ""
}
# 优化主逻辑
optimize_system() {
    echo "Optimizing system priorities..."
    echo ""
    
    wait_for_springboard
    
    # 1. 应用高优先级列表
    if [ ${#HIGH_PRIORITY_LIST[@]} -gt 0 ]; then
        echo "Boosting critical processes (jetsam priority: $HIGH_PRIORITY):"
        echo "If it fails, please try to re-execute it with sudo a1"
        local count=0
        for process in "${HIGH_PRIORITY_LIST[@]}"; do
            local pid=$(_a1_find_pid_by_name "$process")
            if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
                if _a1_set_priority "$pid" "$HIGH_PRIORITY"; then
                    [ "$DEBUG_MODE" = "true" ] && echo "  ✓ $process (PID:$pid) -> $HIGH_PRIORITY"
                    ((count++))
                fi
            else
                [ "$DEBUG_MODE" = "true" ] && echo "  ✗ $process not found"
            fi
        done
        echo "  Adjusted $count processes to priority $HIGH_PRIORITY"
        echo ""
    else
        echo "${A1_YELLOW}Warning: No high priority processes defined${A1_NC}"
        echo ""
    fi
    
    # 2. 应用低优先级列表
    if [ ${#LOW_PRIORITY_LIST[@]} -gt 0 ]; then
        echo "Lowering non-essential processes (jetsam priority: $LOW_PRIORITY):"
        local count=0
        for process in "${LOW_PRIORITY_LIST[@]}"; do
            local pid=$(_a1_find_pid_by_name "$process")
            if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
                if _a1_set_priority "$pid" "$LOW_PRIORITY"; then
                    [ "$DEBUG_MODE" = "true" ] && echo "  ✓ $process (PID:$pid) -> $LOW_PRIORITY"
                    ((count++))
                fi
            else
                [ "$DEBUG_MODE" = "true" ] && echo "  ✗ $process not found"
            fi
        done
        echo "  Adjusted $count processes to priority $LOW_PRIORITY"
        echo ""
    else
        echo "${A1_YELLOW}Warning: No low priority processes defined${A1_NC}"
        echo ""
    fi
    
    # 3. 应用自定义优先级
    apply_custom_priority
    
    echo "_______________________________________________"
    echo "Optimization complete"
    echo "_______________________________________________"
}

# main
main() {
    echo "$(date)"
    echo "__________________"
    echo "|A1 are working..|"
    echo "------------------"
    # 初始化环境
    _a1_init_env
    _a1_colors
    _a1_set_defaults
    # 读取优先级列表
    _a1_read_priority_lists "false"
    # 加载模块
    load_modules
    # 应用内核补丁
    _a1_apply_kernel_patches
    # 调整 launchd
    _a1_adjust_launchd
    # 优化系统
    optimize_system
    # 日志轮迴
    [ "$LOG_REINCARNATION" = "true" ] && [ -f "$jb_a1/a1_tee_log.sh" ] && "$jb_a1/a1_tee_log.sh"
    # 实验功能
    if [ "$EXPERIMENTAL" = "true" ] && [ -f "$jb_a1/a1_experimental.sh" ]; then
        echo "Experimental function..."
        echo "_______________________________"
        "$jb_a1/a1_experimental.sh"
        echo "Done."
        echo "_______________________________________________"
    fi
    # 模式选择
    if [ "$AUTO_ADJUST" = "true" ]; then
        echo "Starting Auto-Adjust (real-time) mode..."
        # _a1_read_priority_lists "true"
        auto_adjust
    elif [ "$SCHEDULED_GUARD" = "true" ]; then
        echo "Starting Scheduled Guard mode..."
        # _a1_read_priority_lists "true"
        scheduled_guard
    elif [ "$LOOP_MODE" = "true" ]; then
        echo "Starting Loop mode..."
        while true; do
            for ((i=$LOOP_SLEEP_INTERVAL; i>=1; i--)); do
                printf "\rNext Circulate Time:%3ds" $i
                sleep 1
            done
            read_a1_config
            [ "$LOOP_MODE" != "true" ] && break
            _a1_read_priority_lists "true"
            echo "Running optimization cycle..."
            optimize_system
        done
    else
        echo "Warning: No monitoring mode enabled." >&2
        exit 0
    fi
    echo "All operations completed successfully"
    sleep 1
}
# run
if [ "$use_sudo_a1" = "false" ]; then
    main 2> >(sudo tee "$jb_a1/a1error.log" >&2) | sudo tee "$jb_a1/a1.log"
else
    main 2> >(tee "$jb_a1/a1error.log" >&2) | tee "$jb_a1/a1.log"
fi

