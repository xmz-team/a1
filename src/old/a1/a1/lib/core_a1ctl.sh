# mod_a1ctl.sh
# Provides all the core features of A1CTL

_A1CtlCoreFilePath=$( cd $(dirname ${BASH_SOURCE[0]} ) && pwd )
source "$_A1CtlCoreFilePath/core_a1.sh"
source "$_A1CtlCoreFilePath/apis/log.sh"
_a1_colors

RED="${A1_RED}"
NC="${A1_NC}"
YELLOW="${A1_YELLOW}"
GREEN="${A1_GREEN}"
BLUE="${A1_BLUE}"

A1_SCRIPT="$jb/usr/local/bin/a1"
A1_RETURN_SCRIPT="$jb/usr/local/bin/a1-return"
A1CTL_SCRIPT="$jb/usr/local/bin/a1ctl"
CONFIG_DIR="$jb_a1"
HIGH_PRIORITY_FILE="$CONFIG_DIR/high_priority.list"
LOW_PRIORITY_FILE="$CONFIG_DIR/low_priority.list"
CUSTOM_PRIORITY_FILE="$CONFIG_DIR/custom_priority.list"
BACKUP_DIR="$CONFIG_DIR/backup"

_a1ctl_echo() { builtin echo -en "$@"; }
_a1ctl_a1_conf() {
    local config_file="$jb_a1/config.conf"
    cat > "$config_file" << 'EOF'
# config.conf
# 通用配置

export Experimental=false
export Log_Reincarnation=false
export loop=false
export Optimize_Interval=1800
export Debug_Mode=true
export use_sudo_all=true
export use_sudo_a1=true
export use_sudo_a1ctl=true
export Loop_Sleep_Interval=5
export use_root_a1ctl=true
export Auto_Apply=false
export Auto_Adjust=false
export SCHEDULED_GUARD=false
export a1_module_switch=false
export Custom_Priority_Enabled=false
export compat_mode=false

# 优先级配置
export High_Priority=0
export Low_Priority=39
export Launchd_Priority=20
export Dynamic_Priority=15

# lock
export lock_use=true

EOF
}

_a1ctl_check_uid() {
    if [ "$EUID" -ne 0 ]; then
        elog "权限不足请使用'sudo'执行"
        exit 1
    fi
}

_a1ctl_init_config() {
    [ -d "$CONFIG_DIR" ] || $jb/usr/bin/mkdir -p "$CONFIG_DIR"
		[ -d "$BACKUP_DIR" ] || $jb/usr/bin/mkdir -p "$BACKUP_DIR"
    [ -f "$HIGH_PRIORITY_FILE" ] || cat > "$HIGH_PRIORITY_FILE" << 'EOF'
SpringBoard
backboardd
syslogd
configd
launchd
UserEventAgent
apsd
mediaserverd
BTServer
locationd
assertiond
mobileassetd
installd
coresymbolicationd
fseventsd
fairplayd
kbd
sysmond
diagnosticextensionsd
reportcrash
SpringBoard
EOF
		[ -f "$LOW_PRIORITY_FILE" ] || cat > "$LOW_PRIORITY_FILE" << 'EOF'
cloudd
itunesstored
geod
assistantd
calaccessd
adid
analyticsd
nsurlsessiond
softwareupdated
ckdiscretionaryd
itunescloudd
com.apple.sbd
cloudphotod
searchd
delete_d
assetsd
imtransferagent
pasteboardagent
cloudpaird
bird
mstreamd
weatherd
nanoweatherprefsd
watchlistd
awdd
triald
rtcreportingd
symptomsd
symptomsd-diag
metrickitd
biomed
revisiond
adprivacyd
aslmanager
logd_helper
siriinferenced
parsec-fbf
parsecd
cloudphotod
photoanalysisd
mediaanalysisd
searchpartyd
appstored
appleaccountd
amsaccountsd
amsengagementd
bookassetd
musiccache
medialibraryd
familycircled
familynotificationd
donotdisturbd
wirelessproxd
nehelper
mapsupportd
navd
destinationd
routined
locationd_helper
fitnesscoachingd
healthrecordsd
activityd
achievementd
gamectrld
sociallayerd
askpermissiond
privacyaccountingd
spindump
tailspind
stackshot
xpcproxy
distnoted
cfprefsd
suggestd
duetexpertd
synceddefaultsd
nanoprefsyncd
nanosystemsettingsd
nanotimekitcompaniond
nanoregistryd
nanoregistrylaunchd
remoted
remotemanagementd
com.apple.MobileSoftwareUpdate.CleanupPreparePathService
com.apple.StreamingUnzipService
com.apple.SiriTTSService.TrialProxy
com.apple.siri-distributed-evaluation
com.apple.VideoSubscriberAccount.DeveloperService
AppPredictionIntentsHelperService
AssetCacheLocatorService
DayStreamProcessorService
EnforcementService
HistoricalAnalyzerService
IDSBlastDoorService
IMDPersistenceAgent
MTLCompilerService
PerfPowerTelemetryClientRegistrationService
TrustedPeersHelper
ThreeBarsXPCService
accountsd
familycontrolsagent
generatestorageagent
icloudpairing
keyboardservicesd
mobileactivationd
mobilebackup
newsd
notificationsd
profiled
screensharingd
softwareupdate
stocksd
storeassetd
storebookkeeperd
storedownloadd
streaming_zip_conduit
touchsetupd
useractivityd
EOF
    [ -f "$CUSTOM_PRIORITY_FILE" ] || cat > "$CUSTOM_PRIORITY_FILE" << 'EOF'
# 自定义优先级格式: 进程名=Jetsam值
# 值范围: 0-99 (Jetsam 0=Nice -20) (Jetsam 39= Nice 19）
# 示例: SpringBoard=0

EOF
}

_a1ctl_check_config_conflict() {
    local config_file="$CONFIG_DIR/config.conf"
    if [ ! -f "$config_file" ]; then
        return 0
    fi

    local loop_mode=$($jb/usr/bin/grep "^export loop=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
    local auto_adjust=$($jb/usr/bin/grep "^export Auto_Adjust=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
    local scheduled_guard=$($jb/usr/bin/grep "^export SCHEDULED_GUARD=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
    local conflicts=0
    # 三个模式互斥
    if [ "$loop_mode" = "true" ] && [ "$auto_adjust" = "true" ]; then
        wlog "循环模式和自动调整不能同时开启"
        ((conflicts++))
    fi
    if [ "$loop_mode" = "true" ] && [ "$scheduled_guard" = "true" ]; then
        wlog "循环模式和定时守护不能同时开启"
        ((conflicts++))
    fi
    if [ "$auto_adjust" = "true" ] && [ "$scheduled_guard" = "true" ]; then
        wlog "自动调整和定时守护不能同时开启"
        ((conflicts++))
    fi

    if [ $conflicts -gt 0 ]; then
        wlog "建议调整配置以避免冲突"
        return 1
    fi
    return 0
}

_a1ctl_save_config() {
    _a1ctl_check_uid
    $jb/usr/bin/mkdir -p "$BACKUP_DIR"
    if [ ! -d "$BACKUP_DIR" ]; then
        elog "无法创建备份目录: $BACKUP_DIR"
        return 1
    fi
    
    local have_files=false
    [ -f "$CONFIG_DIR/config.conf" ] && have_files=true
    [ -f "$HIGH_PRIORITY_FILE" ] && have_files=true
    [ -f "$LOW_PRIORITY_FILE" ] && have_files=true
    [ -f "$CONFIG_DIR/inside.ini" ] && have_files=true
    [ -f "$CONFIG_DIR/$CUSTOM_PRIORITY_FILE" ] && have_files=true

    local custom_priority_file="$CUSTOM_PRIORITY_FILE"
    
    if [ "$have_files" = "false" ]; then
        elog "没有找到任何配置文件"
        return 1
    fi
    
    local temp_dir
    temp_dir=$($jb/usr/bin/mktemp -d "/tmp/a1_backup_XXXXXX")
    if [ ! -d "$temp_dir" ]; then
        elog "无法创建临时目录"
        return 1
    fi
    
    local copied_count=0
    if [ -f "$CONFIG_DIR/config.conf" ]; then
        $jb/usr/bin/cp -p "$CONFIG_DIR/config.conf" "$temp_dir/config.conf" 2>/dev/null || \
        $jb/usr/bin/cp "$CONFIG_DIR/config.conf" "$temp_dir/config.conf"
        ((copied_count++))
    fi
    
    if [ -f "$HIGH_PRIORITY_FILE" ]; then
        $jb/usr/bin/cp -p "$HIGH_PRIORITY_FILE" "$temp_dir/high_priority.list" 2>/dev/null || \
        $jb/usr/bin/cp "$HIGH_PRIORITY_FILE" "$temp_dir/high_priority.list"
        ((copied_count++))
    fi
    
    if [ -f "$LOW_PRIORITY_FILE" ]; then
        $jb/usr/bin/cp -p "$LOW_PRIORITY_FILE" "$temp_dir/low_priority.list" 2>/dev/null || \
        $jb/usr/bin/cp "$LOW_PRIORITY_FILE" "$temp_dir/low_priority.list"
        ((copied_count++))
    fi

    if [ -f "$custom_priority_file" ]; then
        $jb/usr/bin/cp -p "$custom_priority_file" "$temp_dir/custom_priority_file" 2>/dev/null || \
        $jb/usr/bin/cp "$custom_priority_file" "$temp_dir/custom_priority_file"
        ((copied_count++))
    fi
    
    if [ $copied_count -eq 0 ]; then
        $jb/usr/bin/rm -rf "$temp_dir"
        elog "没有文件可以备份"
        return 1
    fi
    
    local timestamp=$($jb/usr/bin/date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config_backup_$timestamp.tar.gz"
    
    cd "$temp_dir" || {
        $jb/usr/bin/rm -rf "$temp_dir"
        return 1
    }
    
    $jb/usr/bin/tar -czf "$backup_file" -- *
    local tar_status=$?
    
    cd - > /dev/null 2>&1
    
    $jb/usr/bin/rm -rf "$temp_dir"
    
    if [ $tar_status -ne 0 ]; then
        elog "创建备份文件失败"
        $jb/usr/bin/rm -f "$backup_file" 2>/dev/null
        return 1
    fi
    
    local file_size
    file_size=$($jb/usr/bin/du -h "$backup_file" | $jb/usr/bin/cut -f1)
    ilog "配置备份成功 (${file_size}B)"
    echo "备份文件: $backup_file"
    
    local backup_count=$($jb/usr/bin/ls "$BACKUP_DIR"/*.tar 2>/dev/null | wc -l)
    if [ $backup_count -gt 10 ]; then
        wlog "备份文件过多($backup_count个), 建议清理"
    fi
    return 0
}

_a1ctl_check_a1_running() {
    if $ps aux | $jb/usr/bin/grep -v "grep" | $jb/usr/bin/grep -v "a1ctl" | $jb/usr/bin/grep -q "[a]1$" || \
       $ps aux | $jb/usr/bin/grep -v "grep" | $jb/usr/bin/grep -v "a1ctl" | $jb/usr/bin/grep -q "$A1_SCRIPT"; then
        return 0
    else
        return 1
    fi
}

_a1ctl_check_if_should_run_a1() {
    local config_file="$CONFIG_DIR/config.conf"
    if [ -f "$config_file" ]; then
        (
            source "$config_file" 2>/dev/null
            [ "${loop:-false}"   = "true" ] ||
            [ "${Auto_Adjust:-false}" = "true" ] ||
            [ "${SCHEDULED_GUARD:-false}" = "true" ]
        ) && return 0
    fi
    return 1
}

_a1ctl_auto_apply_check() {
    local config_file="$CONFIG_DIR/config.conf"

    # 声明所有要用到的变量为局部变量
    local auto_apply loop_mode auto_adjust scheduled_guard

    if [ -f "$config_file" ]; then
        # 直接在函数内 source（因为变量已声明为 local，不会污染全局）
        source "$config_file" 2>/dev/null
        auto_apply="${Auto_Apply:-false}"
        loop_mode="${loop:-false}"
        auto_adjust="${Auto_Adjust:-false}"
        scheduled_guard="${SCHEDULED_GUARD:-false}"
    else
        auto_apply=false
        loop_mode=false
        auto_adjust=false
        scheduled_guard=false
    fi

    if [ "$auto_apply" = "true" ]; then
        _a1ctl_check_config_conflict
        if [ $? -ne 0 ]; then
            elog "配置冲突, 自动应用已停止"
            return
        fi

        ilog "自动应用生效中..."
        _a1ctl_a1_kill_pid > /dev/null 2>&1
        sleep 2

        if [ "$loop_mode" = "true" ] || [ "$auto_adjust" = "true" ] || [ "$scheduled_guard" = "true" ]; then
            _a1ctl_start_a1_service
        else
            wlog "A1未启动"
        fi
    fi
}

_a1ctl_check_status() {
    if _a1ctl_check_a1_running; then
        ilog "A1 正在运行"
        local config_file="$jb_a1/config.conf"
        (
            [ -f "$config_file" ] && source "$config_file" 2>/dev/null
            local loop_mode="${loop:-false}"
            local experimental="${Experimental:-false}"
            local log_reincarnation="${Log_Reincarnation:-false}"
            local custom_priority_enabled="${Custom_Priority_Enabled:-false}"
            local auto_apply="${Auto_Apply:-false}"
            local auto_adjust="${Auto_Adjust:-false}"
            local scheduled_guard="${SCHEDULED_GUARD:-false}"
            local use_sudo_all="${use_sudo_all:-true}"
            local use_sudo_a1="${use_sudo_a1:-true}"
            local use_sudo_a1ctl="${use_sudo_a1ctl:-true}"
            local use_root_a1ctl="${use_root_a1ctl:-true}"
            local a1_module_switch="${a1_module_switch:-false}"
            local compat_mode="${compat_mode:-false}"
            local lock_use="${lock_use:-true}"
            echo "配置状态:"
            [ "$loop_mode" = "true" ] && echo "  ${GREEN}✓${NC} 循环模式" || echo "  ${RED}✗${NC} 循环模式"
            [ "$auto_adjust" = "true" ] && echo "  ${GREEN}✓${NC} 实时自动调整" || echo "  ${RED}✗${NC} 实时自动调整"
            [ "$scheduled_guard" = "true" ] && echo "  ${GREEN}✓${NC} 定时守护" || echo "  ${RED}✗${NC} 定时守护"
            [ "$experimental" = "true" ] && echo "  ${GREEN}✓${NC} 实验功能" || echo "  ${RED}✗${NC} 实验功能"
            [ "$log_reincarnation" = "true" ] && echo "  ${GREEN}✓${NC} 日志轮迴" || echo "  ${RED}✗${NC} 日志轮迴"
            [ "$auto_apply" = "true" ] && echo "  ${GREEN}✓${NC} 自动生效" || echo "  ${RED}✗${NC} 自动生效"
            [ "$custom_priority_enabled" = "true" ] && echo "  ${GREEN}✓${NC} 自定义优先级" || echo "  ${RED}✗${NC} 自定义优先级"
            [ "$use_sudo_all" = "false" ] && echo "  ${GREEN}✓${NC} sudo免密模式" || echo "  ${RED}✗${NC} sudo免密模式"
            [ "$use_sudo_a1" = "false" ] && echo "  ${GREEN}✓${NC} a1 sudo免密" || echo "  ${RED}✗${NC} a1 sudo免密"
            [ "$use_sudo_a1ctl" = "false" ] && echo "  ${GREEN}✓${NC} a1ctl sudo免密" || echo "  ${RED}✗${NC} a1ctl sudo免密"
            [ "$use_root_a1ctl" = "false" ] && echo "  ${GREEN}✓${NC} a1ctl免root模式" || echo "  ${RED}✗${NC} a1ctl免root模式"
            [ "$a1_module_switch" = "true" ] && echo "  ${GREEN}✓${NC} 模块系统" || echo "  ${RED}✗${NC} 模块系统"
            [ "$compat_mode" = "true" ] && echo "  ${GREEN}✓${NC} 兼容模式" || echo "  ${RED}✗${NC} 兼容模式"
            # 保留原逻辑（原代码中 true 输出"已關閉"）
            [ "$lock_use" = "true" ] && echo "  ${GREEN}info${NC} lock 已關閉" || echo "  ${RED}info${NC} 已開啟"
        )
        _a1ctl_check_config_conflict
    else
        elog "A1 未运行"
    fi
}

_a1ctl_start_a1() {
    echo "启动 A1 优化..."
    
    # check
    if _a1ctl_check_a1_running; then
        wlog "A1 已经在运行中"
        echo "使用 'a1ctl restart' 重启 A1"
        return 0
    fi
    
    # clean
    _a1ctl_a1_kill_pid
    sleep 2
    
    if [ -x "$A1_SCRIPT" ]; then
        echo "正在启动 A1..."
        
        # 后台启动 A1，使用 nohup 避免进程被挂起
        nohup bash "$A1_SCRIPT" > /dev/null 2>&1 &
        local pid=$!


        sleep 1
        
        # check2
        if ps -p $pid > /dev/null 2>&1; then
            ilog "A1 已启动 (PID: $pid)"
            
            # 等待一段时间再次检查进程状态
            sleep 2
            
            if ! ps -p $pid > /dev/null 2>&1; then
                elog "A1 进程异常退出"
                ilog "请检查日志或配置"
                return 1
            fi
            
            return 0
        else
            elog "A1 启动失败"
            
            # 尝试不同的启动方式
            ilog "尝试备用启动方式..."
            bash "$A1_SCRIPT" &
            local pid2=$!
            sleep 1
            
            if ps -p $pid2 > /dev/null 2>&1; then
                ilog "A1 已启动 (PID: $pid2，备用方式)"
                return 0
            else
                elog "备用启动方式也失败"
                return 1
            fi
        fi
    else
        elog "找不到 A1 脚本 $A1_SCRIPT"
        
        # 尝试查找 A1 脚本
        local found_a1=$(which a1 2>/dev/null || find $jb -name "a1" -type f 2>/dev/null | head -1)
        if [ -n "$found_a1" ] && [ -x "$found_a1" ]; then
            wlog "找到 A1 脚本: $found_a1"
            echo "是否尝试使用此脚本启动？ [y/N]: "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                nohup bash "$found_a1" > /dev/null 2>&1 &
                ilog "已尝试启动"
                return 0
            fi
        fi
        
        return 1
    fi
}

_a1ctl_start_a1_service() {
    ilog "检查配置..."
    _a1ctl_check_config_conflict
    if [ $? -ne 0 ]; then
        elog "配置冲突, 启动已停止"
        return
    fi

    _a1ctl_a1_kill_pid > /dev/null 2>&1
    sleep 1
    
    if [ -f "$A1_SCRIPT" ]; then
        ilog "拉起A1服务..."
        nohup bash "$A1_SCRIPT" > /dev/null 2>&1 &
        local pid=$!
        sleep 2
        if ps -p $pid > /dev/null 2>&1; then
            ilog "A1已启动 (PID: $pid)"
        else
            elog "A1启动失败"
        fi
    else
        elog "找不到 A1 脚本 $A1_SCRIPT"
    fi
}

_a1ctl_start_a1_foreground() {
    echo "启动 A1 优化（前台模式）..."
    _a1ctl_a1_kill_pid
    sleep 1
    echo "_______________________________________________"
    
    if [ -x "$A1_SCRIPT" ]; then
        exec "$A1_SCRIPT"
    else
        elog "找不到 A1 脚本 $A1_SCRIPT"
    fi
}

_a1ctl_a1_kill_pid() {
    local A1_PROCESSES=$($ps aux | $jb/usr/bin/grep -v "grep" | $jb/usr/bin/grep -v "a1ctl" | $jb/usr/bin/grep -E "(a1$|$A1_SCRIPT)" | $jb/usr/bin/awk '{print $2}')
    local count=0
    for PID in $A1_PROCESSES; do
        if [ "$PID" -ne "$$" ] && [ "$PID" -ne "$PPID" ] && [ -n "$PID" ]; then
            ilog "结束 a1 进程 PID: $PID"
            kill -TERM "$PID" 2>/dev/null
            sleep 0.5
            if ps -p "$PID" >/dev/null 2>&1; then
                kill -KILL "$PID" 2>/dev/null
            fi
            ((count++))
        fi
    done
    
    if [ $count -gt 0 ]; then
        echo "已清理 $count 个旧进程"
    fi
    $ps -eo pid,state,comm | $jb/usr/bin/grep -w Z | $jb/usr/bin/grep -w a1 | $jb/usr/bin/awk '{print $1}' | xargs -r kill -9 2>/dev/null
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

_a1ctl_update_config() {
    local key="export $1"
    local value="$2"
    local config_file="$jb_a1/config.conf"

    $jb/usr/bin/mkdir -p "$jb_a1"

    if [ ! -f "$config_file" ]; then
        _a1ctl_a1_conf
    fi

    if $jb/usr/bin/grep -q "^$key=" "$config_file"; then
        $jb/usr/bin/sed -i "s/^$key=.*/$key=$value/" "$config_file"
    else
        echo "$key=$value" >> "$config_file"
    fi

    ilog "已更新配置: $key=$value"
}

_a1ctl_set_auto_apply() {
    _a1ctl_check_uid
    case "$1" in
        "on"|"true"|"enable")
            _a1ctl_update_config "Auto_Apply" "true"
            ilog "自动生效已开启"
            _a1ctl_auto_apply_check
            ;;
        "off"|"false"|"disable")
            _a1ctl_update_config "Auto_Apply" "false"
            ilog "自动生效已关闭"
            ;;
        *)
            elog "使用: auto-apply <on|off>"
            ;;
    esac
}

_a1ctl_show_config() {
    local config_file="$jb_a1/config.conf"
    if [ -f "$config_file" ]; then
        echo "当前配置:"
        echo "----------------"
        cat "$config_file"
        echo "----------------"
        (
            source "$config_file" 2>/dev/null
            echo "优先级设置:"
            echo "  高优先级: renice -20 (jetsam ${High_Priority:-0})"
            echo "  低优先级: renice 19  (jetsam ${Low_Priority:-39})"
            echo "  launchd:  renice 0   (jetsam ${Launchd_Priority:-20})"
            echo "循环设置:"
            echo "  循环休眠: ${Loop_Sleep_Interval:-5} 秒"
            echo "其他设置:"
            echo "  自动生效:             ${Auto_Apply:-false}"
            echo "  实时自动调整:         ${Auto_Adjust:-false}"
            echo "  定时守护:             ${SCHEDULED_GUARD:-false}"
            echo "  sudo免密模式 (all):   ${use_sudo_all:-true}"
            echo "  sudo免密模式 (a1):    ${use_sudo_a1:-true}"
            echo "  sudo免密模式 (a1ctl): ${use_sudo_a1ctl:-true}"
            echo "  免root执行a1ctl:       ${use_root_a1ctl:-true}"
            echo "  兼容模式:             ${compat_mode:-false}"
        )
    else
        cat << 'EOF'
使用默认配置:
    Experimental=false
    Log_Reincarnation=false
    loop=false
    Optimize_Interval=1800
    Debug_Mode=true
    High_Priority=0
    Low_Priority=39
    Launchd_Priority=20
    Loop_Sleep_Interval=5
    Auto_Apply=false
    Auto_Adjust=false
    SCHEDULED_GUARD=false
    use_sudo_all=true
    use_sudo_a1=true
    use_sudo_a1ctl=true
    use_root_a1ctl=true
    compat_mode=false
EOF
    fi
}

_a1ctl_add_priority() {
    _a1ctl_check_uid
    
    if [ -z "$2" ]; then
        elog "使用: add <high|low> <进程名> 或 add <进程名> <优先级值>"
        return 1
    fi
    
    case "$2" in
        "high"|"h")
            if [ -z "$3" ]; then
                elog "请提供进程名"
                return 1
            fi
            
            if [ -f "$HIGH_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$3$" "$HIGH_PRIORITY_FILE"; then
                wlog "进程 '$3' 已在高优先级列表中"
                return 0
            fi
            
            echo "$3" >> "$HIGH_PRIORITY_FILE"
            ilog "已添加 '$3' 到高优先级列表"
            _a1ctl_auto_apply_check
            ;;
            
        "low"|"l")
            if [ -z "$3" ]; then
                elog "请提供进程名"
                return 1
            fi
            
            if [ -f "$LOW_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$3$" "$LOW_PRIORITY_FILE"; then
                wlog "进程 '$3' 已在低优先级列表中"
                return 0
            fi
            
            echo "$3" >> "$LOW_PRIORITY_FILE"
            ilog "已添加 '$3' 到低优先级列表"
            auto_apply_check
            ;;
            
        *)
            # 自定义优先级
            if [ -z "$3" ]; then
                elog "请提供优先级数值 (0-99)"
                return 1
            fi
            
            if [[ ! "$3" =~ ^[0-9]+$ ]] || [ "$3" -lt 0 ] || [ "$3" -gt 99 ]; then
                elog "优先级数值必须在 0-99 之间"
                return 1
            fi
            
            local process_name="$2"
            local priority="$3"
            
            if $jb/usr/bin/grep -q "^$process_name=" "$CUSTOM_PRIORITY_FILE"; then
                $jb/usr/bin/sed -i "/^$process_name=/d" "$CUSTOM_PRIORITY_FILE"
            fi
            
            echo "$process_name=$priority" >> "$CUSTOM_PRIORITY_FILE"
            ilog "已添加自定义优先级: $process_name=$priority"
            _a1ctl_auto_apply_check
            ;;
    esac
}

_a1ctl_remove_priority() {
    _a1ctl_check_uid
    if [ -z "$2" ]; then
        elog "使用: remove <进程名>"
        return 1
    fi
    
    local process_name="$2"
    local removed=0
    
    # 从高优先级列表移除
    if [ -f "$HIGH_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$process_name$" "$HIGH_PRIORITY_FILE"; then
        $jb/usr/bin/sed -i "/^$process_name$/d" "$HIGH_PRIORITY_FILE"
        ilog "已从高优先级列表移除 '$process_name'"
        removed=1
    fi
    
    # 从低优先级列表移除
    if [ -f "$LOW_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$process_name$" "$LOW_PRIORITY_FILE"; then
        $jb/usr/bin/sed -i "/^$process_name$/d" "$LOW_PRIORITY_FILE"
        ilog "已从低优先级列表移除 '$process_name'"
        removed=1
    fi
    
    # 从自定义优先级列表移除
    if [ -f "$CUSTOM_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$process_name=" "$CUSTOM_PRIORITY_FILE"; then
        $jb/usr/bin/sed -i "/^$process_name=/d" "$CUSTOM_PRIORITY_FILE"
        ilog "已从自定义优先级列表移除 '$process_name'"
        removed=1
    fi
    
    if [ $removed -eq 0 ]; then
        elog "进程 '$process_name' 不在任何优先级列表中"
        return 1
    fi
    
    _a1ctl_auto_apply_check
}

_a1ctl_list_priority() {
    case "$2" in
        "high"|"h")
            if [ -f "$HIGH_PRIORITY_FILE" ]; then
                echo "高优先级进程列表:"
                echo "------------------"
                cat "$HIGH_PRIORITY_FILE"
                echo "------------------"
                local count=$($jb/usr/bin/wc -l < "$HIGH_PRIORITY_FILE")
                echo "共 $count 个高优先级进程"
            else
                echo "高优先级列表文件不存在"
            fi
            ;;
            
        "low"|"l")
            if [ -f "$LOW_PRIORITY_FILE" ]; then
                echo "低优先级进程列表:"
                echo "------------------"
                cat "$LOW_PRIORITY_FILE"
                echo "------------------"
                local count=$($jb/usr/bin/wc -l < "$LOW_PRIORITY_FILE")
                echo "共 $count 个低优先级进程"
            else
                echo "低优先级列表文件不存在"
            fi
            ;;
            
        "custom"|"c")
            if [ -f "$CUSTOM_PRIORITY_FILE" ]; then
                echo "自定义优先级列表:"
                echo "------------------"
                cat "$CUSTOM_PRIORITY_FILE"
                echo "------------------"
                local count=$($jb/usr/bin/grep -c "=" "$CUSTOM_PRIORITY_FILE" 2>/dev/null || echo "0")
                echo "共 $count 个自定义优先级设置"
            else
                echo "自定义优先级列表文件不存在"
            fi
            ;;
            
        *)
            echo "使用: list <high|low|custom>"
            echo "或简写: list <h|l|c>"
            ;;
    esac
}

_a1ctl_clear_priority() {
    _a1ctl_check_uid
    case "$2" in
        "high"|"h")
            echo "确定要清空高优先级列表吗？ (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                > "$HIGH_PRIORITY_FILE"
                ilog "已清空高优先级列表"
                _a1ctl_auto_apply_check
            else
                ilog "取消操作"
            fi
            ;;
            
        "low"|"l")
            echo "确定要清空低优先级列表吗？ (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                > "$LOW_PRIORITY_FILE"
                ilog "已清空低优先级列表"
                _a1ctl_auto_apply_check
            else
                ilog "取消操作"
            fi
            ;;
            
        "custom"|"c")
            echo "确定要清空自定义优先级列表吗？ (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                > "$CUSTOM_PRIORITY_FILE"
                local _show_custom_file="\
# 自定义优先级格式: 进程名=优先级值
# 优先级值范围: 0-99
# 示例: SpringBoard=0
"
                printf "$_show_custom_file" >> "$CUSTOM_PRIORITY_FILE"
                ilog "已清空自定义优先级列表"
                _a1ctl_auto_apply_check
            else
                ilog "取消操作"
            fi
            ;;
            
        *)
            echo "使用: clear <high|low|custom>"
            echo "或简写: clear <h|l|c>"
            ;;
    esac
}

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

_a1ctl_a1_compat_mode() {
    _a1ctl_check_uid
    if [ "$2" = "on" ]; then
        _a1ctl_update_config "compat_mode" "true"
        (
            if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
                cd "$jb/var" || exit 1
                ln -sf "$jb" ./
                ln -sf "$jb/a1" ./
            fi
        )
        ilog "兼容模式已开启"
    elif [ "$2" = "off" ]; then
        _a1ctl_update_config "compat_mode" "false"
        ilog "兼容模式已关闭"
    else
        elog "使用: compat <on|off>"
    fi
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

_a1ctl_set_priority_value() {
    _a1ctl_check_uid
    local priority_type="$2"
    local value="$3"
    
    if [ -z "$priority_type" ] || [ -z "$value" ]; then
        elog "使用: set <high|low|launchd> <数值>"
        return 1
    fi
    
    if [[ ! "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 0 ] || [ "$value" -gt 39 ]; then
        elog "优先级数值必须在 0-39 之间"
        return 1
    fi
    
    case "$priority_type" in
        "high"|"h")
            _a1ctl_update_config "High_Priority" "$value"
            ;;
        "low"|"l")
            _a1ctl_update_config "Low_Priority" "$value"
            ;;
        "launchd"|"lchd")
            _a1ctl_update_config "Launchd_Priority" "$value"
            ;;
        *)
            elog "无效的优先级类型: $priority_type (使用: high, low, launchd)"
            return 1
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
