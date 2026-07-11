#!/bin/bash
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    jb=""
fi
jb_a1="$jb/a1"
source "$jb_a1/lib/loadenv.sh"
source "$jb_a1/lib/core_pm.sh"
_a1_init_env

show_help() {
    cat << EOF
用法: $0 [命令] [参数]

命令:
  repo-add <名称> <URL>   添加远端仓库
  repo-remove <名称>      删除远端仓库
  repo-list               列出所有仓库
  sync [仓库名]           同步仓库索引
  search <关键词>         搜索远端包
  list-remote [仓库]      列出远端可用包
  info <包名>             显示远端包详细信息
  install-remote <包名>   从远端安装包
  upgrade [包名]          升级模块
  check-updates           检查可用更新
  help                    显示此帮助信息

示例:
  # 添加仓库并安装
  $0 repo-add official https://repo.example.com/a1-modules
  $0 sync
  $0 search example
  $0 info example-module
  $0 install-remote example-module
  # 更新
  $0 check-updates
  $0 upgrade
EOF
}

load_modules() {
    source "$jb_a1/load_mod.sh"
    load_modules_common "a1module"
}

main() {
    check_commands
    # 先不使用加载模块，因为pm刚出来还不稳定
    # load_modules >/dev/null
    # echo "a1module module loaded/open"
    local command="${1:-help}"
    shift || true
    case "$command" in
        repo-add)
            [ -z "$1" ] && { elog "用法: repo-add <url>"; exit 1; }
            add_repo "$1"
            ;;
        repo-remove)
            [ -z "$1" ] && { elog "用法: repo-remove <name>"; exit 1; }
            remove_repo "$1"
            ;;
        repo-list) list_repos ;;
        sync) sync_repo_metadata "$1" ;;
        search)
            [ -z "$1" ] && { elog "用法: search <关键词>"; exit 1; }
            search_remote "$1"
            ;;
        list-remote) list_remote "$1" ;;
        info)
            [ -z "$1" ] && { elog "用法: info <包名>"; exit 1; }
            show_remote_info "$1"
            ;;
        install-remote)
            [ -z "$1" ] && { elog "用法: install-remote <包名>"; exit 1; }
            install_remote "$1"
            ;;
        upgrade) upgrade_modules "$1" ;;
        check-updates) check_updates ;;
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

