#!/bin/bash
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    jb=""
fi
jb_a1="$jb/a1"
source "$jb_a1/lib/loadenv.sh"
source "$jb_a1/lib/core_mod.sh"
_a1_init_env

show_help() {
    if [ "$a1ctl_call_mod" = "true" ]; then
        local script_name="a1ctl mod"
    else
        local script_name="$0"
    fi
    local official_modules=$(ls "$a1_expand/official/modules" 2>/dev/null || echo "无")
    cat << EOF
Usage: $script_name [command] [option]
  init                    初始化模块系统
  list                    列出所有已安装模块
  package <目录>          打包模块
  install <文件>          从本地文件安装模块
  remove <模块ID>         删除模块
  enable <模块ID>         启用模块
  disable <模块ID>        禁用模块
  help                    显示此帮助信息

官方扩展包:
  $official_modules

示例:
  $script_name init
  $script_name list
  $script_name package ./my-module
  $script_name install my-module.a1module.zip
EOF
}

load_modules() {
    source "$jb_a1/load_mod.sh"
    load_modules_common "a1module"
}

main() {
    # get lock
    if ! acquire_lock; then
        exit 1
    fi
    trap release_lock EXIT INT TERM
    check_commands
    load_modules >/dev/null
    # echo "a1module module loaded/open"
    local command="${1:-help}"
    shift || true
    case "$command" in
        init) init_system ;;
        list) list_modules ;;
        package|pack)
            if [ -z "$1" ]; then
                elog "請指定要打包的目錄"
                exit 1
            fi
            package_module "$1" "${2:-.}"
            ;;
        install)
            if [ -z "$1" ]; then
                elog "請指定要安裝的模塊文件"
                exit 1
            fi
            install_module "$1" "${2:-false}"
            ;;
        disable)
            if [ -z "$1" ]; then
                elog "請指定要禁用的模塊ID"
                exit 1
            fi
            disable_module "$1"
            ;;
        load) load_modules ;;
        remove)
            if [ -z "$1" ]; then
                elog "請指定要刪除的模塊ID"
                exit 1
            fi
            remove_module "$1"
            ;;
        help|--help|-h) show_help ;;
        *)
            elog "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi

