# mod_a1ctl.sh
# Provides all the core features of A1CTL

_A1CtlCoreFilePath=$( cd $(dirname ${BASH_SOURCE[0]} ) && pwd )
source "$_A1CtlCoreFilePath/core_a1.sh"
source "$_A1CtlCoreFilePath/apis/log.sh"

_a1ctl_check_uid() {
    if [ "$EUID" -ne 0 ]; then
        elog "权限不足请使用'sudo'执行"
        exit 1
    fi
}













_a1ctl_return_priority() {
    _a1ctl_check_uid
    if [ -f "$A1_RETURN_SCRIPT" ]; then
        echo "恢复进程优先级..."
        "$A1_RETURN_SCRIPT"
        ilog "优先级已恢复"
    else
        elog "找不到 a1-return 脚本 $A1_RETURN_SCRIPT"
    fi
}








: '
_a1ctl_configure_sudo_permissions() {
    local mode="$1"
    local target="$2"
    local sudoers_dir="$jb/etc/sudoers.d"
    local procursus_file="$sudoers_dir/procursus"
    
    if [ -z "$mode" ] || [ -z "$target" ]; then
        elog "使用: sudo <on|off> <a1|a1ctl|all>"
        return 1
    fi

    case "$target" in
        "a1")
            local a1_line="mobile ALL=(ALL) NOPASSWD: $jb/usr/local/bin/a1"
            if [ "$mode" = "on" ]; then
                if sudo grep -q "^$a1_line\$" "$procursus_file"; then
                    ilog "a1 已在 sudoers 中"
                else
                    echo -e "\n$a1_line" | sudo tee -a "$procursus_file" > /dev/null
                    ilog "a1 sudo 权限已开启"
                fi
                _a1ctl_update_config "use_sudo_a1" "false"
            elif [ "$mode" = "off" ]; then
                if sudo grep -q "^$a1_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1_line\$|d" "$procursus_file"
                    ilog "a1 sudo 权限已关闭"
                else
                    ilog "a1 不在 sudoers 中"
                fi
                _a1ctl_update_config "use_sudo_a1" "true"
            else
                elog "无效的模式: $mode"
                return 1
            fi
            ;;

        "a1ctl")
            local a1ctl_line="mobile ALL=(ALL) NOPASSWD: $jb/usr/local/bin/a1ctl"
            if [ "$mode" = "on" ]; then
                if sudo grep -q "^$a1ctl_line\$" "$procursus_file"; then
                    wlog "a1ctl 已在 sudoers 中"
                else
                    echo -e "\n$a1ctl_line" | sudo tee -a "$procursus_file" > /dev/null
                    ilog "a1ctl sudo 权限已开启"
                fi
                _a1ctl_update_config "use_sudo_a1ctl" "false"
            elif [ "$mode" = "off" ]; then
                if sudo grep -q "^$a1ctl_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1ctl_line\$|d" "$procursus_file"
                    ilog "a1ctl sudo 权限已关闭"
                else
                    wlog "a1ctl 不在 sudoers 中"
                fi
                _a1ctl_update_config "use_sudo_a1ctl" "true"
            else
                elog "无效的模式: $mode"
                return 1
            fi
            ;;

        "all")
            local a1_line="mobile ALL=(ALL) NOPASSWD: $jb/usr/local/bin/a1"
            local a1ctl_line="mobile ALL=(ALL) NOPASSWD: $jb/usr/local/bin/a1ctl"
            if [ "$mode" = "on" ]; then
                if ! sudo grep -q "^$a1_line\$" "$procursus_file"; then
                    echo -e "\n$a1_line" | sudo tee -a "$procursus_file" > /dev/null
                fi

                if ! sudo grep -q "^$a1ctl_line\$" "$procursus_file"; then
                    echo -e "\n$a1ctl_line" | sudo tee -a "$procursus_file" > /dev/null
                fi
                ilog "a1 和 a1ctl sudo 权限已开启"
                _a1ctl_update_config "use_sudo_all" "false"
            elif [ "$mode" = "off" ]; then
                if sudo grep -q "^$a1_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1_line\$|d" "$procursus_file"
                fi

                if sudo grep -q "^$a1ctl_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1ctl_line\$|d" "$procursus_file"
                fi
                ilog "a1 和 a1ctl sudo 权限已关闭"
                _a1ctl_update_config "use_sudo_all" "true"
            else
                elog "无效的模式: $mode"
                return 1
            fi
            ;;
        *)
            elog "无效的目标: $target (使用: a1, a1ctl, all)"
            return 1
            ;;
    esac
}

_a1ctl_conf_use_root() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        elog "使用: root <on|off>"
        return 1
    fi

    if [ "$2" = "on" ]; then
        _a1ctl_update_config "use_root_a1ctl" "false"
        ilog "已开启root执行模式"
    elif [ "$2" = "off" ]; then
        _a1ctl_update_config "use_root_a1ctl" "true"
        ilog "已关闭root执行模式"
    else
        elog "无效的选择: $2"
        return 1
    fi
}
'

_a1ctl_restore_config() {
    _a1ctl_check_uid

    if [ ! -d "$BACKUP_DIR" ]; then
        elog "备份目录不存在: $BACKUP_DIR"
        return 1
    fi

    local backup_files=()
    local file_count=0

    for backup_file in "$BACKUP_DIR"/config_backup_*.tar "$BACKUP_DIR"/config_backup_*.tar.gz; do
        if [ -f "$backup_file" ]; then
            backup_files+=("$backup_file")
            ((file_count++))
        fi
    done
    
    if [ ${#backup_files[@]} -eq 0 ]; then
        elog "没有找到备份文件"
        echo "备份文件夹: $BACKUP_DIR"
        echo "支持的格式: config_backup_YYYYMMDD_HHMMSS.tar 或 .tar.gz"
        return 1
    fi

    local sorted_backups=($(printf '%s\n' "${backup_files[@]}" | sort -r))
    
    echo "可用备份文件 (最新的在前面):"
    echo "----------------"
    for i in "${!sorted_backups[@]}"; do
        local filepath="${sorted_backups[$i]}"
        local filename=$(basename "$filepath")
        local timestamp=$(echo "$filename" | sed 's/config_backup_//' | sed 's/\.tar\(\.gz\)\?$//')
        local date_str=$(echo "$timestamp" | $jb/usr/bin/cut -d'_' -f1 2>/dev/null || echo "未知日期")
        local time_str=$(echo "$timestamp" | $jb/usr/bin/cut -d'_' -f2 2>/dev/null || echo "未知时间")

        local file_size="未知大小"
        if [ -f "$filepath" ]; then
            file_size=$($jb/usr/bin/du -h "$filepath" 2>/dev/null | $jb/usr/bin/cut -f1 || echo "未知")
        fi
        
        echo "  [$i] ${date_str:0:4}-${date_str:4:2}-${date_str:6:2} ${time_str:0:2}:${time_str:2:2}:${time_str:4:2} (${file_size}B)"
        echo "      文件: $filename"
    done
    echo "----------------"

    echo "请输入要恢复的备份编号 (0-$(( ${#sorted_backups[@]} - 1 ))): "
    read -r choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -ge ${#sorted_backups[@]} ]; then
        elog "无效的选择"
        return 1
    fi
    
    local selected_file="${sorted_backups[$choice]}"

    if [ ! -f "$selected_file" ] || [ ! -s "$selected_file" ]; then
        elog "备份文件无效或为空"
        return 1
    fi

    ilog "正在验证备份文件..."
    local tar_content=""

    if [[ "$selected_file" == *.tar.gz ]]; then
        tar_content=$($jb/usr/bin/tar -tzf "$selected_file" 2>/dev/null)
    else
        tar_content=$($jb/usr/bin/tar -tf "$selected_file" 2>/dev/null)
    fi
    
    if [ $? -ne 0 ] || [ -z "$tar_content" ]; then
        elog "无效的备份文件格式或已损坏"
        return 1
    fi

    local valid_files=0
    echo "$tar_content" | $jb/usr/bin/grep -q "config.conf" && valid_files=$((valid_files + 1))
    echo "$tar_content" | $jb/usr/bin/grep -q "high_priority.list" && valid_files=$((valid_files + 1))
    echo "$tar_content" | $jb/usr/bin/grep -q "low_priority.list" && valid_files=$((valid_files + 1))
    
    if [ $valid_files -eq 0 ]; then
        elog "备份文件中没有找到有效的配置文件"
        echo "文件内容:"
        echo "$tar_content"
        return 1
    fi
    
    ilog "备份文件验证通过 (包含 $valid_files 个配置文件)"

    echo ""
    wlog "这将覆盖当前配置"
    echo "选择的备份文件: $(basename "$selected_file")"
    echo "文件大小: $($jb/usr/bin/du -h "$selected_file" 2>/dev/null | $jb/usr/bin/cut -f1 || echo "未知")"
    echo ""
    echo "包含的文件:"
    echo "$tar_content" | while read -r line; do
        echo "  - $line"
    done
    echo ""
    
    read -p "确定要恢复这个备份吗? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        ilog "取消恢复"
        return 0
    fi

    local temp_dir
    temp_dir=$($jb/usr/bin/mktemp -d "/tmp/a1_restore_XXXXXX")
    if [ ! -d "$temp_dir" ]; then
        elog "无法创建临时目录"
        return 1
    fi

    ilog "正在解压备份文件..."
    if [[ "$selected_file" == *.tar.gz ]]; then
        if ! $jb/usr/bin/tar -xzf "$selected_file" -C "$temp_dir" 2>/dev/null; then
            elog "解压备份文件失败"
            $jb/usr/bin/rm -rf "$temp_dir"
            return 1
        fi
    else
        if ! $jb/usr/bin/tar -xf "$selected_file" -C "$temp_dir" 2>/dev/null; then
            elog "解压备份文件失败"
            $jb/usr/bin/rm -rf "$temp_dir"
            return 1
        fi
    fi

    ilog "正在恢复配置文件..."
    local restored_count=0
    $jb/usr/bin/mkdir -p "$CONFIG_DIR"
    
    if [ -f "$temp_dir/config.conf" ]; then
        if [ -f "$CONFIG_DIR/config.conf" ]; then
            local current_backup="$CONFIG_DIR/config.conf.bak.$(date +%s)"
            $jb/usr/bin/cp -p "$CONFIG_DIR/config.conf" "$current_backup" 2>/dev/null
        fi
        
        $jb/usr/bin/cp -p "$temp_dir/config.conf" "$CONFIG_DIR/config.conf" 2>/dev/null || \
        $jb/usr/bin/cp "$temp_dir/config.conf" "$CONFIG_DIR/config.conf"
        ilog "恢复 config.conf"
        restored_count=$((restored_count + 1))
    fi
    
    if [ -f "$temp_dir/high_priority.list" ]; then
        if [ -f "$HIGH_PRIORITY_FILE" ]; then
            local current_backup="$HIGH_PRIORITY_FILE.bak.$(date +%s)"
            $jb/usr/bin/cp -p "$HIGH_PRIORITY_FILE" "$current_backup" 2>/dev/null
        fi
        
        $jb/usr/bin/cp -p "$temp_dir/high_priority.list" "$HIGH_PRIORITY_FILE" 2>/dev/null || \
        $jb/usr/bin/cp "$temp_dir/high_priority.list" "$HIGH_PRIORITY_FILE"
        ilog "恢复 high_priority.list"
        restored_count=$((restored_count + 1))
    fi
    
    if [ -f "$temp_dir/low_priority.list" ]; then
        if [ -f "$LOW_PRIORITY_FILE" ]; then
            local current_backup="$LOW_PRIORITY_FILE.bak.$(date +%s)"
            $jb/usr/bin/cp -p "$LOW_PRIORITY_FILE" "$current_backup" 2>/dev/null
        fi
        
        $jb/usr/bin/cp -p "$temp_dir/low_priority.list" "$LOW_PRIORITY_FILE" 2>/dev/null || \
        $jb/usr/bin/cp "$temp_dir/low_priority.list" "$LOW_PRIORITY_FILE"
        ilog "恢复 low_priority.list"
        restored_count=$((restored_count + 1))
    fi

    $jb/usr/bin/rm -rf "$temp_dir"
    
    if [ $restored_count -eq 0 ]; then
        wlog "没有找到任何配置文件，但备份文件验证通过"
        echo "这可能是因为文件在临时目录中的路径不同"
        return 1
    fi

    ilog "配置恢复完成 (恢复了 $restored_count 个文件)"
    _a1ctl_check_config_conflict

    _a1ctl_auto_apply_check
    echo ""
    ilog "当前配置已被备份为 .bak.[timestamp] 文件"
    ilog "如果需要撤销恢复，可以手动复制备份文件回来"
    
    return 0
}


_a1ctl_clean_system() {
    _a1ctl_check_uid
    case "$2" in
        "tmp")
            $jb/usr/bin/rm -rf /tmp/* 2>/dev/null
            echo "清理tmp完成"
            ;;
        "apt")
            $jb/usr/bin/rm -rf $jb/var/lib/apt/lists/* 2>/dev/null
            $jb/usr/bin/rm -rf $jb/var/cache/apt/archives/*.deb 2>/dev/null
            echo "清理apt缓存完成"
            ;;
        "logs")
            find /var/log -type f -name "*.log" -exec sh -c '> "{}"' \; 2>/dev/null
            find $jb/var/log -type f -name "*.log" -exec sh -c '> "{}"' \; 2>/dev/null
            find /var/log -type f -name "*.log.*" -exec $jb/usr/bin/rm -f {} \; 2>/dev/null
            find $jb/var/log -type f -name "*.log.*" -exec $jb/usr/bin/rm -f {} \; 2>/dev/null
            echo "清理日志文件完成"
            ;;
        *)
            echo "使用: clean <tmp|apt|logs>"
            ;;
    esac
}


# api {
# 公共api
a1_conf() { _a1ctl_conf; }
check_uid() { _a1ctl_check_uid; }
a1ctl_echo() { _a1ctl_echo "$@"; }
init_config() { _a1ctl_init_config; }
check_config_conflict() { _a1ctl_check_config_conflict; }
save_config() { _a1ctl_save_config; }
check_a1_runing() { _a1ctl_check_a1_running; }
check_if_should_run_a1() { _a1ctl_check_if_should_run_a1; }
auto_apply_check() { _a1ctl_auto_apply_check; }
check_status() { _a1ctl_check_status; }
start_a1() { _a1ctl_start_a1; }
start_a1_service() { _a1ctl_start_a1_service; }
start_a1_foreground() { _a1ctl_start_a1_foreground; }
a1_kill_pid() { _a1ctl_a1_kill_pid; }
return_priority() { _a1ctl_return_priority; }
update_config() { _a1ctl_update_config "$@"; }
set_auto_apply() { _a1ctl_set_auto_apply; }
show_config() { _a1ctl_show_config; }
add_priority() { _a1ctl_add_priority "$@"; }
remove_priority() { _a1ctl_remove_priority "$@"; }
list_piority() { _a1ctl_list_priority "$@"; }
clear_priority() { _a1ctl_clear_priority "$@"; }
configure_sudo_permissions() { _a1ctl_configure_sudo_permissions "$@"; }
conf_usr_root() { _a1ctl_conf_use_root "$@"; }
restore_config() { _a1ctl_restore_config; }
a1_compat_mode() { _a1ctl_a1_compat_mode "$@"; }
clean_system() { _a1ctl_clean_system "$@"; }
set_priority_value() { _a1ctl_set_priority_value "$@"; }
# }

export -f _a1ctl_a1_conf
export -f _a1ctl_check_uid
export -f _a1ctl_echo
export -f _a1ctl_init_config
export -f _a1ctl_check_config_conflict
export -f _a1ctl_save_config
export -f _a1ctl_check_a1_running
export -f _a1ctl_check_if_should_run_a1
export -f _a1ctl_auto_apply_check
export -f _a1ctl_check_status
export -f _a1ctl_start_a1
export -f _a1ctl_start_a1_service
export -f _a1ctl_start_a1_foreground
export -f _a1ctl_a1_kill_pid
export -f _a1ctl_return_priority
export -f _a1ctl_update_config
export -f _a1ctl_set_auto_apply
export -f _a1ctl_show_config
export -f _a1ctl_add_priority
export -f _a1ctl_remove_priority
export -f _a1ctl_list_priority
export -f _a1ctl_clear_priority
export -f _a1ctl_configure_sudo_permissions
export -f _a1ctl_conf_use_root
export -f _a1ctl_restore_config
export -f _a1ctl_a1_compat_mode
export -f _a1ctl_clean_system
export -f _a1ctl_set_priority_value
