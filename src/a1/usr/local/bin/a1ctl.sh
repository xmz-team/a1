#!/bin/bash
# set -x # debug 使用
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    jb=""
fi
jb_a1="$jb/a1"
source "$jb_a1/lib/core_a1ctl.sh"
_a1_init_env
source "$_A1CtlCoreFilePath/lock.sh"

echo() { a1ctl_echo "$@"; }
show_help() {
    local a1_help="\
  __    _       _     _     ___  
 / /\  / |     | |_| | | | | |_) 
/_/--\ |_|     |_| | \_\_/ |_|_) 

作者: LF | 维护者: LF, AD
组织: 1030152896
$(id)

用法: $0 [选项] [命令]

基础命令:
  start                    启动 A1
  stop                     停止 A1
  status                   查看状态
  restart                  重启 A1
  return                   恢复优先级

模式控制:
  loop <on|off>            开启/关闭循环模式
  auto-adjust <on|off>     开启/关闭实时自动调整模式 (1秒轮询)
  scheduled-guard <on|off> 开启/关闭定时守护模式 (15秒轮询)
  exp <on|off>             开启/关闭实验性功能
  olr <on|off>             开启/关闭日志轮迴
  custom <on|off>          开启/关闭自定义优先级

优先级管理:
  add high <进程名>        添加到高优先级列表
  add low <进程名>         添加到低优先级列表
  add <进程名> <值>        添加自定义优先级 (0-99)
  remove <进程名>          从优先级列表移除
  list <high|low|custom>   查看优先级列表
  clear <high|low|custom>  清空优先级列表
  set <类型> <数值>        设置优先级数值

  类型: high, low, launchd*
  数值: 0-39 (Jetsam值)

配置管理:
  config                   查看当前配置
  set-interval <秒数>      设置优化间隔
  loop-sleep <秒数>        设置循环间隔
  auto-apply <on|off>      开启/关闭自动应用
  sudo <on|off> <目标>     管理sudo权限
  root <on|off>            管理root执行模式
  save                     保存当前配置
  restore                  从备份恢复配置
  compat <on|off>          开启/关闭兼容模式

系统维护:
  clean tmp                清理tmp缓存
  clean apt                清理apt缓存
  clean logs               清理日志文件

模块系统:
  mod <on|off>             模块系统开关
  mod init                 初始化模块系统
  mod list                 列出所有模块
  mod pack <目录>          打包模块
  mod install <文件>       安装模块
  mod enable <模块ID>      启用模块
  mod disable <模块ID>     禁用模块
  mod load                 加载启用的模块
  mod remove <模块ID>      删除模块

其他:
  help                     显示此帮助
  -f start                 前台强制启动A1

提示:
  实时自动调整模式: 每秒检查新进程并调整优先级 (更激进)
  定时守护模式: 每15秒检查一次 (更省电)
  循环模式: 传统模式，定期执行完整优化
  配置文件保存在: $BACKUP_DIR
  -20=最高 (Jetsam 0)
  0=默认
  19=最低 (Jetsam 39)
  默认优先级由launchd进程决定
"
    printf "%s\n" "$a1_help";
}

load_modules() {
    if [ "$a1_module_switch" = "false" ]; then
        :
    elif [ "$a1_module_switch" = "true" ]; then
        source "$jb_a1/load_mod.sh"
        load_modules_common "a1ctl"
    else
        elog "unknown key value: $a1_module_switch"
    fi
}

main() {
    init_config
    load_modules >/dev/null 2>&1
    # echo "a1ctl module loaded/open"
    case "$1" in
        "1"|"start") start_a1 ;;
        "0"|"stop") a1_kill_pid; ilog "A1 已停止" ;;
        "restart") a1_kill_pid; sleep 2; start_a1 ;;
        "status") check_status ;;
        "return") return_priority ;;
        # 模式控制命令
        "loop")
            check_uid
            if [ "$2" = "on" ]; then
                # 开启循环模式前关闭其他模式
                update_config "loop" "true"
                update_config "Auto_Adjust" "false"
                update_config "SCHEDULED_GUARD" "false"
                ilog "循环模式已开启（已自动关闭其他模式）"
            elif [ "$2" = "off" ]; then
                update_config "loop" "false"
                ilog "循环模式已关闭"
            else
                elog "使用: loop <on|off>"
            fi
            ;;
        "auto-adjust")
            check_uid
            if [ "$2" = "on" ]; then
                # 开启实时自动调整前关闭其他模式
                update_config "Auto_Adjust" "true"
                update_config "loop" "false"
                update_config "SCHEDULED_GUARD" "false"
                ilog "实时自动调整模式已开启（已自动关闭其他模式）"
            elif [ "$2" = "off" ]; then
                update_config "Auto_Adjust" "false"
                ilog "实时自动调整模式已关闭"
            else
                elog "使用: auto-adjust <on|off>"
            fi
            ;;
        "scheduled-guard"|"guard")
            check_uid
            if [ "$2" = "on" ]; then
                # 开启定时守护前关闭其他模式
                update_config "SCHEDULED_GUARD" "true"
                update_config "loop" "false"
                update_config "Auto_Adjust" "false"
                ilog "定时守护模式已开启（已自动关闭其他模式）"
            elif [ "$2" = "off" ]; then
                update_config "SCHEDULED_GUARD" "false"
								ilog "定时守护模式已关闭"
            else
                elog "使用: scheduled-guard <on|off> 或 guard <on|off>"
            fi
            ;;
        "exp"|"experimental")
            check_uid
            if [ "$2" = "on" ]; then
                update_config "Experimental" "true"
                ilog "实验性功能已开启"
            elif [ "$2" = "off" ]; then
                update_config "Experimental" "false"
                ilog "实验性功能已关闭"
            else
                elog "使用: exp <on|off>"
            fi
            ;;
        "olr")
            check_uid
            if [ "$2" = "on" ]; then
                update_config "Log_Reincarnation" "true"
                echo -e "\nmobile ALL=(ALL) NOPASSWD: $jb_a1/a1_tee_log.sh" | sudo tee -a $jb/etc/sudoers.d/procursus
                ilog "日志轮迴已开启"
            elif [ "$2" = "off" ]; then
                update_config "Log_Reincarnation" "false"
                sed -i '\|^mobile ALL=(ALL) NOPASSWD: $jb_a1/a1_tee_log.sh$|d' $jb/etc/sudoers.d/procursus
                ilog "日志轮迴已关闭"
            else
                elog "使用: olr <on|off>"
            fi
            ;;
        "custom")
            check_uid
            if [ "$2" = "on" ]; then
                update_config "Custom_Priority_Enabled" "true"
                ilog "自定义优先级已开启"
            elif [ "$2" = "off" ]; then
                update_config "Custom_Priority_Enabled" "false"
                ilog "自定义优先级已关闭"
            else
                elog "使用: custom <on|off>"
            fi
            ;;
        # 优先级管理命令
        "add") add_priority "$@" ;;
        "remove") remove_priority "$@" ;;
        "list") list_priority "$@" ;;
        "clear") clear_priority "$@" ;;
        "set") set_priority_value "$@" ;;
        "help"|""|"--help"|"-h"|"h") show_help ;;
        "-f")
            if [ "$2" = "start" ]; then
                start_a1_foreground
            else
                echo "命令错误 $2"
            fi
            ;;
        # 清理命令
        "clean") clean_system "$@" ;;
        # 配置管理命令
        "config"|"show-config") show_config ;;
        "set-interval")
            check_uid
            if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                update_config "Optimize_Interval" "$2"
            else
                elog "请提供有效的秒数"
            fi
            ;;
        "loop-sleep")
            check_uid
            if [[ ! "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ]; then
                elog "循环休眠时间必须是大于0的整数"
                return 1
            fi
            update_config "Loop_Sleep_Interval" "$2"
            ;;
        "auto-apply") set_auto_apply "$2" ;;
        "sudo")
            check_uid; configure_sudo_permissions "$2" "$3" ;;
        "root") check_uid; conf_use_root "$1" "$2" ;;
        "save"|"save-config") save_config ;;
        "restore"|"restore-config") restore_config ;;
        "compat"|"compat-mode") a1_compat_mode "$@" ;;
        "lock")
            if [ -n "$2" ]; then
                if [ "$2" = "on" ]; then
                    update_config "lock_use" "true"
                    ilog "lock 已開啟"
                    ilog "lock 是一種機制, 它能保證程式在運行時不受到其他進程的影響, \n避免意外情況發生(如檔案損壞等)\n但它本身也有缺陷: 只能單進程執行, 無法並發"
                elif [ "$2" = "off" ]; then
                    update_config "lock_use" "false"
                    ilog "lock 已關閉"
                    wlog "lock 已經被關閉了, a1 現在可以進行多線程模式, \n但這樣可能導致配置檔案等資料損壞"
                else
                    elog "請輸入 on/off, 如 $0 $1 on/off, 而不是 $0 $1"
                fi
            else
                elog "請輸入 on/off, 如 $0 $1 on/off, 而不是 $0 $1"
            fi
            ;;
        # 模块系统命令
        "module"|"mod"|"expand")
            if [ $# -eq 1 ] || [ "$2" = "help" ] || [ "$2" = "h" ]; then
                export a1ctl_call_mod="true"
                "$jb/usr/local/bin/a1module" help
                return 0
            fi
            check_uid
            case "$2" in
                "on") update_config "a1_module_switch" "true"; echo "✓ 模块功能已开启" ;;
              "off") update_config "a1_module_switch" "false"; echo "✗ 模块功能已关闭" ;;
                *)
                    if [ ! -x "$jb/usr/local/bin/a1module" ]; then
                        elog "a1module 不存在, 你可能在使用旧版本的A1"
                        return 1
                    fi
                    if [ "$a1_module_switch" != "true" ]; then
                        elog "模块开关是关闭的\n请使用 '$(basename $0) mod on' 开启"
                        return 1
                    fi
                    shift
                    export a1ctl_call_mod="true"
                    "$jb/usr/local/bin/a1module" "$@"
                    ;;
            esac
            ;;
        *)
            elog "未知命令: $1"
            ilog "使用 'a1ctl help' 查看帮助"
            ;;
    esac
}

if [ "$lock_use" = "false" ]; then
    # 不使用锁, 直接执行
    if [ "$(id -u)" = "0" ]; then
        main "$@"
    else
        if [ "$use_root_a1ctl" = "false" ]; then
            a1hub="$(which a1hub 2>/dev/null || echo "$jb/usr/local/bin/a1hub")"
            export a1hub_use_confirm="1"
            exec "$a1hub" "$@"
        else
            if [ -x "$(which a1hub 2>/dev/null)" ]; then
                export a1hub_use_confirm="1"
                exec "$(which a1hub)" "$@"
            else
                export a1hub_use_confirm="1"
                exec "$jb/usr/local/bin/a1hub" "$@"
            fi
            [ $? != 0 ] && elog "a1hub 在哪裡?" && exit 1
        fi
    fi
else
    # 使用鎖
    LOCK_FILE="$jb_a1/lock"
    LOCK_FD=200
    if [ "$a1hub_use_confirm" = "1" ]; then
        main "$@"
    else
        if ! acquire_lock; then
            exit 1
        fi
        trap 'release_lock' EXIT INT TERM
        if [ "$(id -u)" = "0" ]; then
            main "$@"
        else
            if [ "$use_root_a1ctl" = "false" ]; then
                a1hub="$(which a1hub 2>/dev/null || echo "$jb/usr/local/bin/a1hub")"
                export a1hub_use_confirm="1"
                exec "$a1hub" "$@"
            else
                if [ -x "$(which a1hub 2>/dev/null)" ]; then
                    export a1hub_use_confirm="1"
                    exec "$(which a1hub)" "$@"
                else
                    export a1hub_use_confirm="1"
                    exec "$jb/usr/local/bin/a1hub" "$@"
                fi
                [ $? != 0 ] && elog "a1hub 在哪裡?" && exit 1
            fi
        fi
    fi
fi
