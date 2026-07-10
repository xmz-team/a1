#!/bin/bash

# set -x # debug 使用

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

# 导入配置
source "$jb_a1/lib/core.sh"
source "$jb_a1/config.conf"
source "$jb_a1/inside.ini"

# 旧配置兼容
# jb=/var/jb
# ps=/bin/ps
# jb_a1=$jb/a1

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

echo() {
    builtin echo -e "$@"
}

cerr() {
    builtin printf "%b\n" "$*" >&2
}

_a1_conf() {
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

Error_uid_Check_a1() {
    if [ "$EUID" -ne 0 ]; then
        cerr "${RED}[错误]${NC}: ${YELLOW}权限不足${NC}, ${BLUE}请使用'sudo'执行${NC}"
        exit 1
    fi
}

_err_uid_check() {
    Error_uid_Check_a1
}

init_config() {
    if [ ! -d "$CONFIG_DIR" ]; then
        $jb/usr/bin/mkdir -p "$CONFIG_DIR"
    fi

    if [ ! -d "$BACKUP_DIR" ]; then
        $jb/usr/bin/mkdir -p "$BACKUP_DIR"
    fi

    if [ ! -f "$HIGH_PRIORITY_FILE" ]; then
        cat > "$HIGH_PRIORITY_FILE" << 'EOF'
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
    fi
    
    if [ ! -f "$LOW_PRIORITY_FILE" ]; then
        cat > "$LOW_PRIORITY_FILE" << 'EOF'
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
    fi

    if [ ! -f "$CUSTOM_PRIORITY_FILE" ]; then
        cat > "$CUSTOM_PRIORITY_FILE" << 'EOF'
# 自定义优先级格式: 进程名=Jetsam值
# 值范围: 0-99 (Jetsam 0=Nice -20) (Jetsam 39= Nice 19）
# 示例: SpringBoard=0

EOF
    fi
}

check_config_conflict() {
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
        echo "${YELLOW}[警告]${NC}: 循环模式和自动调整不能同时开启"
        ((conflicts++))
    fi
    if [ "$loop_mode" = "true" ] && [ "$scheduled_guard" = "true" ]; then
        echo "${YELLOW}[警告]${NC}: 循环模式和定时守护不能同时开启"
        ((conflicts++))
    fi
    if [ "$auto_adjust" = "true" ] && [ "$scheduled_guard" = "true" ]; then
        echo "${YELLOW}[警告]${NC}: 自动调整和定时守护不能同时开启"
        ((conflicts++))
    fi

    if [ $conflicts -gt 0 ]; then
        echo "${YELLOW}建议: 调整配置以避免冲突${NC}"
        return 1
    fi

    return 0
}

save_config() {
    Error_uid_Check_a1
    
    $jb/usr/bin/mkdir -p "$BACKUP_DIR"
    if [ ! -d "$BACKUP_DIR" ]; then
        cerr "${RED}[错误]${NC}: 无法创建备份目录: $BACKUP_DIR"
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
        echo "${YELLOW}[警告]${NC}: 没有找到任何配置文件"
        return 1
    fi
    
    local temp_dir
    temp_dir=$($jb/usr/bin/mktemp -d "/tmp/a1_backup_XXXXXX")
    if [ ! -d "$temp_dir" ]; then
        cerr "${RED}[错误]${NC}: 无法创建临时目录"
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
        cerr "${RED}[错误]${NC}: 没有文件可以备份"
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
        cerr "${RED}[错误]${NC}: 创建备份文件失败"
        $jb/usr/bin/rm -f "$backup_file" 2>/dev/null
        return 1
    fi
    
    local file_size
    file_size=$($jb/usr/bin/du -h "$backup_file" | $jb/usr/bin/cut -f1)
    echo "${GREEN}✓${NC} 配置备份成功 (${file_size}B)"
    echo "备份文件: $backup_file"
    
    local backup_count=$($jb/usr/bin/ls "$BACKUP_DIR"/*.tar 2>/dev/null | wc -l)
    if [ $backup_count -gt 10 ]; then
        echo "${YELLOW}[信息]${NC}: 备份文件过多($backup_count个), 建议清理"
    fi
    
    return 0
}

check_a1_running() {
    if $ps aux | $jb/usr/bin/grep -v "grep" | $jb/usr/bin/grep -v "a1ctl" | $jb/usr/bin/grep -q "[a]1$" || \
       $ps aux | $jb/usr/bin/grep -v "grep" | $jb/usr/bin/grep -v "a1ctl" | $jb/usr/bin/grep -q "$A1_SCRIPT"; then
        return 0
    else
        return 1
    fi
}

check_if_should_run_a1() {
    local config_file="$CONFIG_DIR/config.conf"
    if [ -f "$config_file" ]; then
        local auto_adjust=$($jb/usr/bin/grep "^export Auto_Adjust=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
        local scheduled_guard=$($jb/usr/bin/grep "^export SCHEDULED_GUARD=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
        local loop_mode=$($jb/usr/bin/grep "^export loop=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
        
        if [ "$auto_adjust" = "true" ] || [ "$scheduled_guard" = "true" ] || [ "$loop_mode" = "true" ]; then
            return 0
        fi
    fi
    return 1
}

auto_apply_check() {
    local config_file="$CONFIG_DIR/config.conf"
    if [ -f "$config_file" ]; then
        local auto_apply=$($jb/usr/bin/grep "^export Auto_Apply=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
        if [ "$auto_apply" = "true" ]; then
            check_config_conflict
            if [ $? -ne 0 ]; then
                cerr "${RED}[错误]${NC}: 配置冲突, 自动应用已停止"
                return
            fi

            echo "${BLUE}自动应用生效中...${NC}"
            a1_kill_pid > /dev/null 2>&1
            sleep 2
            local loop_mode=$($jb/usr/bin/grep "^export loop=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            local auto_adjust=$($jb/usr/bin/grep "^export Auto_Adjust=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            local scheduled_guard=$($jb/usr/bin/grep "^export SCHEDULED_GUARD=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            
            if [ "$loop_mode" = "true" ] || [ "$auto_adjust" = "true" ] || [ "$scheduled_guard" = "true" ]; then
                start_a1_service
            else
                cerr "${YELLOW}A1未启动${NC}"
            fi
        fi
    fi
}

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

check_status() {
    if check_a1_running; then
        echo "${GREEN}✓ A1 正在运行${NC}"

        local config_file="$jb_a1/config.conf"
        local loop_mode="false"
        local experimental="false"
        local log_reincarnation="false"
        local custom_priority_enabled="false"
        local auto_apply="false"
        local auto_adjust="false"
        local scheduled_guard="false"
        local use_sudo_all="false"
        local use_sudo_a1="false"
        local use_sudo_a1ctl="false"
        local use_root_a1ctl="true"
        local a1_module_switch="false"
        local compat_mode="false"
        local lock_use="true"

        if [ -f "$config_file" ]; then
            loop_mode=$($jb/usr/bin/grep "^export loop=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            experimental=$($jb/usr/bin/grep "^export Experimental=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            log_reincarnation=$($jb/usr/bin/grep "^export Log_Reincarnation=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            auto_apply=$($jb/usr/bin/grep "^export Auto_Apply=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            auto_adjust=$($jb/usr/bin/grep "^export Auto_Adjust=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            scheduled_guard=$($jb/usr/bin/grep "^export SCHEDULED_GUARD=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            custom_priority_enabled=$($jb/usr/bin/grep "^export Custom_Priority_Enabled=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            use_sudo_all=$($jb/usr/bin/grep "^export use_sudo_all=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "true")
            use_sudo_a1=$($jb/usr/bin/grep "^export use_sudo_a1=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "true")
            use_sudo_a1ctl=$($jb/usr/bin/grep "^export use_sudo_a1ctl=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "true")
            use_root_a1ctl=$($jb/usr/bin/grep "^export use_root_a1ctl=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "true")
            a1_module_switch=$($jb/usr/bin/grep "^export a1_module_switch=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            compat_mode=$($jb/usr/bin/grep "^export compat_mode=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "false")
            lock_use=$($jb/usr/bin/grep "^export lock_use=" "$config_file" | $jb/usr/bin/cut -d'=' -f2 | tr -d '[:space:]' || echo "true")
        fi
        
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

        [ "$lock_use" = "true" ] && echo "  ${GREEN}info${NC} lock 已關閉" || echo "  ${RED}info${NC} 已開啟"
        
        check_config_conflict
    else
        echo "${RED}✗ A1 未运行${NC}\n"
    fi
}

start_a1() {
    echo "启动 A1 优化..."
    
    # check
    if check_a1_running; then
        echo "${YELLOW}[警告]${NC}: A1 已经在运行中"
        echo "使用 'a1ctl restart' 重启 A1"
        return 0
    fi
    
    # clean
    a1_kill_pid
    sleep 2
    
    if [ -x "$A1_SCRIPT" ]; then
        echo "正在启动 A1..."
        
        # 后台启动 A1，使用 nohup 避免进程被挂起
        nohup bash "$A1_SCRIPT" > /dev/null 2>&1 &
        local pid=$!


        sleep 1
        
        # check2
        if ps -p $pid > /dev/null 2>&1; then
            echo "${GREEN}✓ A1 已启动 (PID: $pid)${NC}"
            
            # 等待一段时间再次检查进程状态
            sleep 2
            
            if ! ps -p $pid > /dev/null 2>&1; then
                echo "${RED}✗ A1 进程异常退出${NC}"
                echo "请检查日志或配置"
                return 1
            fi
            
            return 0
        else
            echo "${RED}✗ A1 启动失败${NC}"
            
            # 尝试不同的启动方式
            echo "${YELLOW}尝试备用启动方式...${NC}"
            bash "$A1_SCRIPT" &
            local pid2=$!
            sleep 1
            
            if ps -p $pid2 > /dev/null 2>&1; then
                echo "${GREEN}✓ A1 已启动 (PID: $pid2，备用方式)${NC}"
                return 0
            else
                echo "${RED}✗ 备用启动方式也失败${NC}"
                return 1
            fi
        fi
    else
        cerr "${RED}错误: 找不到 A1 脚本 $A1_SCRIPT${NC}"
        
        # 尝试查找 A1 脚本
        local found_a1=$(which a1 2>/dev/null || find $jb -name "a1" -type f 2>/dev/null | head -1)
        if [ -n "$found_a1" ] && [ -x "$found_a1" ]; then
            echo "${YELLOW}找到 A1 脚本: $found_a1${NC}"
            echo "是否尝试使用此脚本启动？ [y/N]: "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                nohup bash "$found_a1" > /dev/null 2>&1 &
                echo "${GREEN}✓ 已尝试启动${NC}"
                return 0
            fi
        fi
        
        return 1
    fi
}

start_a1_service() {
    echo "检查配置..."
    check_config_conflict
    if [ $? -ne 0 ]; then
        cerr "${RED}[错误]${NC}: 配置冲突, 启动已停止"
        return
    fi

    a1_kill_pid > /dev/null 2>&1
    sleep 1
    
    if [ -f "$A1_SCRIPT" ]; then
        echo "${BLUE}拉起A1服务...${NC}"
        nohup bash "$A1_SCRIPT" > /dev/null 2>&1 &
        local pid=$!
        sleep 2
        if ps -p $pid > /dev/null 2>&1; then
            echo "${GREEN}✓ A1已启动 (PID: $pid)${NC}"
        else
            cerr "${RED}✗ A1启动失败${NC}"
        fi
    else
        cerr "${RED}错误: 找不到 A1 脚本 $A1_SCRIPT${NC}"
    fi
}

start_a1_foreground() {
    echo "启动 A1 优化（前台模式）..."
    a1_kill_pid
    sleep 1
    echo "_______________________________________________"
    
    if [ -x "$A1_SCRIPT" ]; then
        exec "$A1_SCRIPT"
    else
        cerr "${RED}错误: 找不到 A1 脚本 $A1_SCRIPT${NC}"
    fi
}

a1_kill_pid() {
    local A1_PROCESSES=$($ps aux | $jb/usr/bin/grep -v "grep" | $jb/usr/bin/grep -v "a1ctl" | $jb/usr/bin/grep -E "(a1$|$A1_SCRIPT)" | $jb/usr/bin/awk '{print $2}')
    local count=0
    for PID in $A1_PROCESSES; do
        if [ "$PID" -ne "$$" ] && [ "$PID" -ne "$PPID" ] && [ -n "$PID" ]; then
            echo "结束 a1 进程 PID: $PID"
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

return_priority() {
    Error_uid_Check_a1
    if [ -f "$A1_RETURN_SCRIPT" ]; then
        echo "恢复进程优先级..."
        "$A1_RETURN_SCRIPT"
        echo "${GREEN}✓ 优先级已恢复${NC}"
    else
        cerr "${RED}错误: 找不到 a1-return 脚本 $A1_RETURN_SCRIPT${NC}"
    fi
}

update_config() {
    local key="export $1"
    local value="$2"
    local config_file="$jb_a1/config.conf"

    $jb/usr/bin/mkdir -p "$jb_a1"

    if [ ! -f "$config_file" ]; then
        _a1_conf
    fi

    if $jb/usr/bin/grep -q "^$key=" "$config_file"; then
        $jb/usr/bin/sed -i "s/^$key=.*/$key=$value/" "$config_file"
    else
        echo "$key=$value" >> "$config_file"
    fi

    echo "${GREEN}✓${NC} 已更新配置: $key=$value"
    # if [ "$key" != "Auto_Apply" ]; then
    #     auto_apply_check
    # fi
}

set_auto_apply() {
    Error_uid_Check_a1
    case "$1" in
        "on"|"true"|"enable")
            update_config "Auto_Apply" "true"
            echo "${GREEN}✓${NC} 自动生效已开启"
            auto_apply_check
            ;;
        "off"|"false"|"disable")
            update_config "Auto_Apply" "false"
            echo "${RED}✗${NC} 自动生效已关闭"
            ;;
        *)
            cerr "${RED}[错误]${NC}: ${YELLOW}使用: auto-apply <on|off>${NC}"
            ;;
    esac
}

show_config() {
    local config_file="$jb_a1/config.conf"
    
    if [ -f "$config_file" ]; then
        echo "当前配置:"
        echo "----------------"
        cat "$config_file"
        echo "----------------"
        echo "优先级设置:"
        echo "  高优先级: renice -20 (jetsam $($jb/usr/bin/grep "^export High_Priority=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "0"))"  
        echo "  低优先级: renice 19 (jetsam $($jb/usr/bin/grep "^export Low_Priority=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "39"))"
        echo "  launchd: renice 0 (jetsam $($jb/usr/bin/grep "^export Launchd_Priority=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "20"))"
        echo "循环设置:"
        echo "  循环休眠: $($jb/usr/bin/grep "^export Loop_Sleep_Interval=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "5") 秒"
        echo "其他设置:"
        echo "  自动生效: $($jb/usr/bin/grep "^export Auto_Apply=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "false")"
        echo "  实时自动调整: $($jb/usr/bin/grep "^export Auto_Adjust=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "false")"
        echo "  定时守护: $($jb/usr/bin/grep "^export SCHEDULED_GUARD=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "false")"
        echo "  a1ctl|a1的sudo免密模式: $($jb/usr/bin/grep "^export use_sudo_all=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "true")"
        echo "  a1的sudo免密模式: $($jb/usr/bin/grep "^export use_sudo_a1=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "true")"
        echo "  a1ctl的sudo免密模式: $($jb/usr/bin/grep "^export use_sudo_a1ctl=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "true")"
        echo "  免root执行a1ctl模式: $($jb/usr/bin/grep "^export use_root_a1ctl=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "true")"
        echo "  兼容模式: $($jb/usr/bin/grep "^export compat_mode=" "$config_file" 2>/dev/null | $jb/usr/bin/cut -d'=' -f2 || echo "false")"
    else
        local cat_conf_acq="\
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
"
        printf "$cat_conf_acq";
    fi
}

add_priority() {
    Error_uid_Check_a1
    
    if [ -z "$2" ]; then
        cerr "${RED}[错误]${NC}: ${YELLOW}使用: add <high|low> <进程名> 或 add <进程名> <优先级值>${NC}"
        return 1
    fi
    
    case "$2" in
        "high"|"h")
            if [ -z "$3" ]; then
                cerr "${RED}[错误]${NC}: ${YELLOW}请提供进程名${NC}"
                return 1
            fi
            
            if [ -f "$HIGH_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$3$" "$HIGH_PRIORITY_FILE"; then
                echo "${YELLOW}[警告]${NC}: 进程 '$3' 已在高优先级列表中"
                return 0
            fi
            
            echo "$3" >> "$HIGH_PRIORITY_FILE"
            echo "${GREEN}✓${NC} 已添加 '$3' 到高优先级列表"
            auto_apply_check
            ;;
            
        "low"|"l")
            if [ -z "$3" ]; then
                cerr "${RED}[错误]${NC}: ${YELLOW}请提供进程名${NC}"
                return 1
            fi
            
            if [ -f "$LOW_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$3$" "$LOW_PRIORITY_FILE"; then
                echo "${YELLOW}[警告]${NC}: 进程 '$3' 已在低优先级列表中"
                return 0
            fi
            
            echo "$3" >> "$LOW_PRIORITY_FILE"
            echo "${GREEN}✓${NC} 已添加 '$3' 到低优先级列表"
            auto_apply_check
            ;;
            
        *)
            # 自定义优先级
            if [ -z "$3" ]; then
                cerr "${RED}[错误]${NC}: ${YELLOW}请提供优先级数值 (0-99)${NC}"
                return 1
            fi
            
            if [[ ! "$3" =~ ^[0-9]+$ ]] || [ "$3" -lt 0 ] || [ "$3" -gt 99 ]; then
                cerr "${RED}[错误]${NC}: ${YELLOW}优先级数值必须在 0-99 之间${NC}"
                return 1
            fi
            
            local process_name="$2"
            local priority="$3"
            
            if $jb/usr/bin/grep -q "^$process_name=" "$CUSTOM_PRIORITY_FILE"; then
                $jb/usr/bin/sed -i "/^$process_name=/d" "$CUSTOM_PRIORITY_FILE"
            fi
            
            echo "$process_name=$priority" >> "$CUSTOM_PRIORITY_FILE"
            echo "${GREEN}✓${NC} 已添加自定义优先级: $process_name=$priority"
            auto_apply_check
            ;;
    esac
}

remove_priority() {
    Error_uid_Check_a1
    
    if [ -z "$2" ]; then
        cerr "${RED}[错误]${NC}: ${YELLOW}使用: remove <进程名>${NC}"
        return 1
    fi
    
    local process_name="$2"
    local removed=0
    
    # 从高优先级列表移除
    if [ -f "$HIGH_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$process_name$" "$HIGH_PRIORITY_FILE"; then
        $jb/usr/bin/sed -i "/^$process_name$/d" "$HIGH_PRIORITY_FILE"
        echo "${GREEN}✓${NC} 已从高优先级列表移除 '$process_name'"
        removed=1
    fi
    
    # 从低优先级列表移除
    if [ -f "$LOW_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$process_name$" "$LOW_PRIORITY_FILE"; then
        $jb/usr/bin/sed -i "/^$process_name$/d" "$LOW_PRIORITY_FILE"
        echo "${GREEN}✓${NC} 已从低优先级列表移除 '$process_name'"
        removed=1
    fi
    
    # 从自定义优先级列表移除
    if [ -f "$CUSTOM_PRIORITY_FILE" ] && $jb/usr/bin/grep -q "^$process_name=" "$CUSTOM_PRIORITY_FILE"; then
        $jb/usr/bin/sed -i "/^$process_name=/d" "$CUSTOM_PRIORITY_FILE"
        echo "${GREEN}✓${NC} 已从自定义优先级列表移除 '$process_name'"
        removed=1
    fi
    
    if [ $removed -eq 0 ]; then
        cerr "${RED}[错误]${NC} 进程 '$process_name' 不在任何优先级列表中"
        return 1
    fi
    
    auto_apply_check
}

list_priority() {
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

clear_priority() {
    Error_uid_Check_a1
    
    case "$2" in
        "high"|"h")
            echo -n "确定要清空高优先级列表吗？ (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                > "$HIGH_PRIORITY_FILE"
                echo "${GREEN}✓${NC} 已清空高优先级列表"
                auto_apply_check
            else
                echo "${YELLOW}取消操作${NC}"
            fi
            ;;
            
        "low"|"l")
            echo -n "确定要清空低优先级列表吗？ (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                > "$LOW_PRIORITY_FILE"
                echo "${GREEN}✓${NC} 已清空低优先级列表"
                auto_apply_check
            else
                echo "${YELLOW}取消操作${NC}"
            fi
            ;;
            
        "custom"|"c")
            echo -n "确定要清空自定义优先级列表吗？ (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                > "$CUSTOM_PRIORITY_FILE"
                local _show_custom_file="\
# 自定义优先级格式: 进程名=优先级值
# 优先级值范围: 0-99
# 示例: SpringBoard=0
"
                printf "$_show_custom_file" >> "$CUSTOM_PRIORITY_FILE"
                echo "${GREEN}✓${NC} 已清空自定义优先级列表"
                auto_apply_check
            else
                echo "${YELLOW}取消操作${NC}"
            fi
            ;;
            
        *)
            echo "使用: clear <high|low|custom>"
            echo "或简写: clear <h|l|c>"
            ;;
    esac
}

configure_sudo_permissions() {
    local mode="$1"
    local target="$2"
    local sudoers_dir="$jb/etc/sudoers.d"
    local procursus_file="$sudoers_dir/procursus"
    
    if [ -z "$mode" ] || [ -z "$target" ]; then
        cerr "${RED}[错误]${NC}: ${YELLOW}使用: sudo <on|off> <a1|a1ctl|all>${NC}"
        return 1
    fi

    case "$target" in
        "a1")
            local a1_line="mobile ALL=(ALL) NOPASSWD: $jb/usr/local/bin/a1"
            if [ "$mode" = "on" ]; then
                if sudo grep -q "^$a1_line\$" "$procursus_file"; then
                    echo "${YELLOW}[信息]${NC}: a1 已在 sudoers 中"
                else
                    echo -e "\n$a1_line" | sudo tee -a "$procursus_file" > /dev/null
                    echo "${GREEN}✓${NC} a1 sudo 权限已开启"
                fi
                update_config "use_sudo_a1" "false"
            elif [ "$mode" = "off" ]; then
                if sudo grep -q "^$a1_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1_line\$|d" "$procursus_file"
                    echo "${GREEN}✓${NC} a1 sudo 权限已关闭"
                else
                    echo "${YELLOW}[信息]${NC}: a1 不在 sudoers 中"
                fi
                update_config "use_sudo_a1" "true"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}无效的模式: $mode${NC}"
                return 1
            fi
            ;;

        "a1ctl")
            local a1ctl_line="mobile ALL=(ALL) NOPASSWD: $jb/usr/local/bin/a1ctl"
            if [ "$mode" = "on" ]; then
                if sudo grep -q "^$a1ctl_line\$" "$procursus_file"; then
                    echo "${YELLOW}[信息]${NC}: a1ctl 已在 sudoers 中"
                else
                    echo -e "\n$a1ctl_line" | sudo tee -a "$procursus_file" > /dev/null
                    echo "${GREEN}✓${NC} a1ctl sudo 权限已开启"
                fi
                update_config "use_sudo_a1ctl" "false"
            elif [ "$mode" = "off" ]; then
                if sudo grep -q "^$a1ctl_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1ctl_line\$|d" "$procursus_file"
                    echo "${GREEN}✓${NC} a1ctl sudo 权限已关闭"
                else
                    echo "${YELLOW}[信息]${NC}: a1ctl 不在 sudoers 中"
                fi
                update_config "use_sudo_a1ctl" "true"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}无效的模式: $mode${NC}"
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
                echo "${GREEN}✓${NC} a1 和 a1ctl sudo 权限已开启"
                update_config "use_sudo_all" "false"
            elif [ "$mode" = "off" ]; then
                if sudo grep -q "^$a1_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1_line\$|d" "$procursus_file"
                fi

                if sudo grep -q "^$a1ctl_line\$" "$procursus_file"; then
                    sudo sed -i "\|^$a1ctl_line\$|d" "$procursus_file"
                fi
                echo "${GREEN}✓${NC} a1 和 a1ctl sudo 权限已关闭"
                update_config "use_sudo_all" "true"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}无效的模式: $mode${NC}"
                return 1
            fi
            ;;
        *)
            cerr "${RED}[错误]${NC}: ${YELLOW}无效的目标: $target (使用: a1, a1ctl, all)${NC}"
            return 1
            ;;
    esac
}

conf_use_root() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        cerr "${RED}[错误]${NC}: ${YELLOW}使用: root <on|off>${NC}"
        return 1
    fi

    if [ "$2" = "on" ]; then
        update_config "use_root_a1ctl" "false"
        echo "${GREEN}✓${NC} 已开启root执行模式"
    elif [ "$2" = "off" ]; then
        update_config "use_root_a1ctl" "true"
        echo "${GREEN}✓${NC} 已关闭root执行模式"
    else
        cerr "${RED}[错误]${NC}: ${YELLOW}无效的选择: $2 ${NC}"
        return 1
    fi
}

restore_config() {
    Error_uid_Check_a1

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "${RED}[错误]${NC}: 备份目录不存在: $BACKUP_DIR"
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
        echo "${RED}[错误]${NC}: 没有找到备份文件"
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

    echo -n "请输入要恢复的备份编号 (0-$(( ${#sorted_backups[@]} - 1 ))): "
    read -r choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -ge ${#sorted_backups[@]} ]; then
        echo "${RED}[错误]${NC}: 无效的选择"
        return 1
    fi
    
    local selected_file="${sorted_backups[$choice]}"

    if [ ! -f "$selected_file" ] || [ ! -s "$selected_file" ]; then
        echo "${RED}[错误]${NC}: 备份文件无效或为空"
        return 1
    fi

    echo "${YELLOW}正在验证备份文件...${NC}"
    local tar_content=""

    if [[ "$selected_file" == *.tar.gz ]]; then
        tar_content=$($jb/usr/bin/tar -tzf "$selected_file" 2>/dev/null)
    else
        tar_content=$($jb/usr/bin/tar -tf "$selected_file" 2>/dev/null)
    fi
    
    if [ $? -ne 0 ] || [ -z "$tar_content" ]; then
        echo "${RED}[错误]${NC}: 无效的备份文件格式或已损坏"
        return 1
    fi

    local valid_files=0
    echo "$tar_content" | $jb/usr/bin/grep -q "config.conf" && valid_files=$((valid_files + 1))
    echo "$tar_content" | $jb/usr/bin/grep -q "high_priority.list" && valid_files=$((valid_files + 1))
    echo "$tar_content" | $jb/usr/bin/grep -q "low_priority.list" && valid_files=$((valid_files + 1))
    
    if [ $valid_files -eq 0 ]; then
        echo "${RED}[错误]${NC}: 备份文件中没有找到有效的配置文件"
        echo "文件内容:"
        echo "$tar_content"
        return 1
    fi
    
    echo "${GREEN}✓${NC} 备份文件验证通过 (包含 $valid_files 个配置文件)"

    echo ""
    echo "${YELLOW}警告: 这将覆盖当前配置${NC}"
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
        echo "${YELLOW}取消恢复${NC}"
        return 0
    fi

    local temp_dir
    temp_dir=$($jb/usr/bin/mktemp -d "/tmp/a1_restore_XXXXXX")
    if [ ! -d "$temp_dir" ]; then
        echo "${RED}[错误]${NC}: 无法创建临时目录"
        return 1
    fi

    echo "${BLUE}正在解压备份文件...${NC}"
    if [[ "$selected_file" == *.tar.gz ]]; then
        if ! $jb/usr/bin/tar -xzf "$selected_file" -C "$temp_dir" 2>/dev/null; then
            echo "${RED}[错误]${NC}: 解压备份文件失败"
            $jb/usr/bin/rm -rf "$temp_dir"
            return 1
        fi
    else
        if ! $jb/usr/bin/tar -xf "$selected_file" -C "$temp_dir" 2>/dev/null; then
            echo "${RED}[错误]${NC}: 解压备份文件失败"
            $jb/usr/bin/rm -rf "$temp_dir"
            return 1
        fi
    fi

    echo "${BLUE}正在恢复配置文件...${NC}"
    local restored_count=0
    $jb/usr/bin/mkdir -p "$CONFIG_DIR"
    
    if [ -f "$temp_dir/config.conf" ]; then
        if [ -f "$CONFIG_DIR/config.conf" ]; then
            local current_backup="$CONFIG_DIR/config.conf.bak.$(date +%s)"
            $jb/usr/bin/cp -p "$CONFIG_DIR/config.conf" "$current_backup" 2>/dev/null
        fi
        
        $jb/usr/bin/cp -p "$temp_dir/config.conf" "$CONFIG_DIR/config.conf" 2>/dev/null || \
        $jb/usr/bin/cp "$temp_dir/config.conf" "$CONFIG_DIR/config.conf"
        echo "${GREEN}✓${NC} 恢复 config.conf"
        restored_count=$((restored_count + 1))
    fi
    
    if [ -f "$temp_dir/high_priority.list" ]; then
        if [ -f "$HIGH_PRIORITY_FILE" ]; then
            local current_backup="$HIGH_PRIORITY_FILE.bak.$(date +%s)"
            $jb/usr/bin/cp -p "$HIGH_PRIORITY_FILE" "$current_backup" 2>/dev/null
        fi
        
        $jb/usr/bin/cp -p "$temp_dir/high_priority.list" "$HIGH_PRIORITY_FILE" 2>/dev/null || \
        $jb/usr/bin/cp "$temp_dir/high_priority.list" "$HIGH_PRIORITY_FILE"
        echo "${GREEN}✓${NC} 恢复 high_priority.list"
        restored_count=$((restored_count + 1))
    fi
    
    if [ -f "$temp_dir/low_priority.list" ]; then
        if [ -f "$LOW_PRIORITY_FILE" ]; then
            local current_backup="$LOW_PRIORITY_FILE.bak.$(date +%s)"
            $jb/usr/bin/cp -p "$LOW_PRIORITY_FILE" "$current_backup" 2>/dev/null
        fi
        
        $jb/usr/bin/cp -p "$temp_dir/low_priority.list" "$LOW_PRIORITY_FILE" 2>/dev/null || \
        $jb/usr/bin/cp "$temp_dir/low_priority.list" "$LOW_PRIORITY_FILE"
        echo "${GREEN}✓${NC} 恢复 low_priority.list"
        restored_count=$((restored_count + 1))
    fi

    $jb/usr/bin/rm -rf "$temp_dir"
    
    if [ $restored_count -eq 0 ]; then
        echo "${YELLOW}[警告]${NC}: 没有找到任何配置文件，但备份文件验证通过"
        echo "这可能是因为文件在临时目录中的路径不同"
        return 1
    fi

    echo "${GREEN}✓${NC} 配置恢复完成 (恢复了 $restored_count 个文件)"
    check_config_conflict

    auto_apply_check
    echo ""
    echo "${YELLOW}提示: 当前配置已被备份为 .bak.[timestamp] 文件${NC}"
    echo "如果需要撤销恢复，可以手动复制备份文件回来"
    
    return 0
}

a1_compat_mode() {
    _err_uid_check
    if [ "$2" = "on" ]; then
        update_config "compat_mode" "true"
        (
            if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
                cd "$jb/var" || exit 1
                ln -sf "$jb" ./
                ln -sf "$jb/a1" ./
            fi
        )
        echo "${GREEN}✓${NC} 兼容模式已开启"
    elif [ "$2" = "off" ]; then
        update_config "compat_mode" "false"
        echo "${GREEN}✓${NC} 兼容模式已关闭"
    else
        cerr "${RED}[错误]${NC}: ${YELLOW}使用: compat <on|off>${NC}"
    fi
}

clean_system() {
    Error_uid_Check_a1
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

set_priority_value() {
    Error_uid_Check_a1
    local priority_type="$2"
    local value="$3"
    
    if [ -z "$priority_type" ] || [ -z "$value" ]; then
        cerr "${RED}[错误]${NC}: ${YELLOW}使用: set <high|low|launchd> <数值>${NC}"
        return 1
    fi
    
    if [[ ! "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 0 ] || [ "$value" -gt 39 ]; then
        cerr "${RED}[错误]${NC}: ${YELLOW}优先级数值必须在 0-39 之间${NC}"
        return 1
    fi
    
    case "$priority_type" in
        "high"|"h")
            update_config "High_Priority" "$value"
            ;;
        "low"|"l")
            update_config "Low_Priority" "$value"
            ;;
        "launchd"|"lchd")
            update_config "Launchd_Priority" "$value"
            ;;
        *)
            cerr "${RED}[错误]${NC}: ${YELLOW}无效的优先级类型: $priority_type (使用: high, low, launchd)${NC}"
            return 1
            ;;
    esac
}

load_modules() {
    if [ "$a1_module_switch" = "false" ]; then
        :
    elif [ "$a1_module_switch" = "true" ]; then
        source "$jb_a1/load_mod.sh"
        load_modules_common "a1ctl"
    else
        cerr "${RED}[Error]${NC}: unknown key value: $a1_module_switch"
    fi
}

main() {
    init_config
    load_modules >/dev/null 2>&1 # 0099
    # echo "a1ctl module loaded/open"
    case "$1" in
        "1"|"start")
            start_a1
            ;;
        "0"|"stop")
            a1_kill_pid
            echo "${GREEN}✓ A1 已停止${NC}"
            ;;
        "restart")
            a1_kill_pid
            sleep 2
            start_a1
            ;;
        "status")
            check_status
            ;;
        "return")
            return_priority
            ;;
            
        # 模式控制命令
        "loop")
            Error_uid_Check_a1
            if [ "$2" = "on" ]; then
                # 开启循环模式前关闭其他模式
                update_config "loop" "true"
                update_config "Auto_Adjust" "false"
                update_config "SCHEDULED_GUARD" "false"
                echo "${GREEN}✓${NC} 循环模式已开启（已自动关闭其他模式）"
            elif [ "$2" = "off" ]; then
                update_config "loop" "false"
                echo "${GREEN}✓${NC} 循环模式已关闭"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}使用: loop <on|off>${NC}"
            fi
            ;;
            
        "auto-adjust")
            Error_uid_Check_a1
            if [ "$2" = "on" ]; then
                # 开启实时自动调整前关闭其他模式
                update_config "Auto_Adjust" "true"
                update_config "loop" "false"
                update_config "SCHEDULED_GUARD" "false"
                echo "${GREEN}✓${NC} 实时自动调整模式已开启（已自动关闭其他模式）"
            elif [ "$2" = "off" ]; then
                update_config "Auto_Adjust" "false"
                echo "${GREEN}✓${NC} 实时自动调整模式已关闭"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}使用: auto-adjust <on|off>${NC}"
            fi
            ;;
            
        "scheduled-guard"|"guard")
            Error_uid_Check_a1
            if [ "$2" = "on" ]; then
                # 开启定时守护前关闭其他模式
                update_config "SCHEDULED_GUARD" "true"
                update_config "loop" "false"
                update_config "Auto_Adjust" "false"
                echo "${GREEN}✓${NC} 定时守护模式已开启（已自动关闭其他模式）"
            elif [ "$2" = "off" ]; then
                update_config "SCHEDULED_GUARD" "false"
                echo "${GREEN}✓${NC} 定时守护模式已关闭"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}使用: scheduled-guard <on|off> 或 guard <on|off>${NC}"
            fi
            ;;
            
        "exp"|"experimental")
            Error_uid_Check_a1
            if [ "$2" = "on" ]; then
                update_config "Experimental" "true"
                echo "${GREEN}✓${NC} 实验性功能已开启"
            elif [ "$2" = "off" ]; then
                update_config "Experimental" "false"
                echo "${GREEN}✓${NC} 实验性功能已关闭"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}使用: exp <on|off>${NC}"
            fi
            ;;
            
        "olr")
            Error_uid_Check_a1
            if [ "$2" = "on" ]; then
                update_config "Log_Reincarnation" "true"
                echo -e "\nmobile ALL=(ALL) NOPASSWD: $jb_a1/a1_tee_log.sh" | sudo tee -a $jb/etc/sudoers.d/procursus
                echo "${GREEN}✓${NC} 日志轮迴已开启"
            elif [ "$2" = "off" ]; then
                update_config "Log_Reincarnation" "false"
                sed -i '\|^mobile ALL=(ALL) NOPASSWD: $jb_a1/a1_tee_log.sh$|d' $jb/etc/sudoers.d/procursus
                echo "${GREEN}✓${NC} 日志轮迴已关闭"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}使用: olr <on|off>${NC}"
            fi
            ;;
            
        "custom")
            Error_uid_Check_a1
            if [ "$2" = "on" ]; then
                update_config "Custom_Priority_Enabled" "true"
                echo "${GREEN}✓${NC} 自定义优先级已开启"
            elif [ "$2" = "off" ]; then
                update_config "Custom_Priority_Enabled" "false"
                echo "${GREEN}✓${NC} 自定义优先级已关闭"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}使用: custom <on|off>${NC}"
            fi
            ;;
            
        # 优先级管理命令
        "add")
            add_priority "$@"
            ;;
            
        "remove")
            remove_priority "$@"
            ;;
            
        "list")
            list_priority "$@"
            ;;
            
        "clear")
            clear_priority "$@"
            ;;
            
        "set")
            set_priority_value "$@"
            ;;
            
        "help"|""|"--help"|"-h"|"h")
            show_help
            ;;
            
        "-f")
            if [ "$2" = "start" ]; then
                start_a1_foreground
            else
                echo "命令错误 $2"
            fi
            ;;
            
        # 清理命令
        "clean")
            clean_system "$@"
            ;;
            
        # 配置管理命令
        "config"|"show-config")
            show_config
            ;;
            
        "set-interval")
            Error_uid_Check_a1
            if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                update_config "Optimize_Interval" "$2"
            else
                cerr "${RED}[错误]${NC}: ${YELLOW}请提供有效的秒数${NC}"
            fi
            ;;
            
        "loop-sleep")
            Error_uid_Check_a1
            if [[ ! "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ]; then
                cerr "${RED}[错误]${NC}: ${YELLOW}循环休眠时间必须是大于0的整数${NC}"
                return 1
            fi
            update_config "Loop_Sleep_Interval" "$2"
            ;;
            
        "auto-apply")
            set_auto_apply "$2"
            ;;
            
        "sudo")
            _err_uid_check
            configure_sudo_permissions "$2" "$3"
            ;;
            
        "root")
            _err_uid_check
            conf_use_root "$1" "$2"
            ;;
            
        "save"|"save-config")
            save_config
            ;;
            
        "restore"|"restore-config")
            restore_config
            ;;
            
        "compat"|"compat-mode")
            a1_compat_mode "$@"
            ;;

        # lock - 3333
        "lock")
            if [ -n "$2" ]; then
                if [ "$2" = "on" ]; then
                    update_config "lock_use" "true"
                    echo "${BLUE}info${NC}: lock 已開啟"
                    echo "lock 是一種機制, 它能保證程式在運行時不受到其他進程的影響, \n避免意外情況發生(如檔案損壞等)\n但它本身也有缺陷: 只能單進程執行, 無法並發"
                elif [ "$2" = "off" ]; then
                    update_config "lock_use" "false"
                    echo "${BLUE}info${NC}: lock 已關閉"
                    echo "lock 已經被關閉了, a1 現在可以進行多線程模式, \n但這樣可能導致配置檔案等資料損壞"
                else
                    cerr "${RED}[Error]${NC}: 請輸入 on/off, 如 $0 $1 on/off, 而不是 $0 $1"
                fi
            else
                cerr "${RED}[Error]${NC}: 請輸入 on/off, 如 $0 $1 on/off, 而不是 $0 $1"
            fi
            ;;

        # 模块系统命令
        "module"|"mod"|"expand")
            if [ $# -eq 1 ] || [ "$2" = "help" ] || [ "$2" = "h" ]; then
                export a1ctl_call_mod="true"
                "$jb/usr/local/bin/a1module" help
                return 0
            fi

            _err_uid_check
    
            case "$2" in
                "on")
                    update_config "a1_module_switch" "true"
                    echo "✓ 模块功能已开启"
                    ;;
              "off")
                    update_config "a1_module_switch" "false"
                    echo "✗ 模块功能已关闭"
                    ;;
                *)
                    if [ ! -x "$jb/usr/local/bin/a1module" ]; then
                        cerr "a1module 不存在, 你可能在使用旧版本的A1"
                        return 1
                    fi

                    if [ "$a1_module_switch" != "true" ]; then
                        cerr "模块开关是关闭的\n请使用 '$(basename $0) mod on' 开启"
                        return 1
                    fi

                    shift
                    export a1ctl_call_mod="true"
                    "$jb/usr/local/bin/a1module" "$@"
                    ;;
            esac
            ;;
            
        *)
            cerr "${RED}[命令未找到]${NC} ${YELLOW}未知命令: $1${NC}"
            cerr "${BLUE}使用 'a1ctl help' 查看帮助${NC}"
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
                exec "$(which a1hub)"
            else
                export a1hub_use_confirm="1"
                exec "$jb/usr/local/bin/a1hub"
            fi
            [ $? != 0 ] && cerr "${RED}[Error]${NC}: a1hub 在哪裡?" && exit 1
        fi
    fi
else
    # 使用鎖
    LOCK_FILE="$jb_a1/lock"
    LOCK_FD=200

    cleanup_stale_lock() {
        if [ -f "$LOCK_FILE" ]; then
            local old_pid
            old_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
            if [ -z "$old_pid" ] || ! kill -0 "$old_pid" 2>/dev/null; then
                rm -f "$LOCK_FILE"
            fi
        fi
    }

    acquire_lock() {
        cleanup_stale_lock
        eval "exec $LOCK_FD>\"$LOCK_FILE\""
        if ! $flock -n $LOCK_FD; then
            local lock_pid
            lock_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
            if [ -n "$lock_pid" ]; then
                cerr "${RED}[Error]${NC}: lock 正在被進程 $lock_pid 持有中,無法繼續操作..."
            else
                cerr "${RED}[Error]${NC}: 無法取得 lock"
            fi
            return 1
        fi
        echo "$$" > "$LOCK_FILE"
        return 0
    }

    release_lock() {
        if [ -f "$LOCK_FILE" ]; then
            local lock_pid
            lock_pid="$(cat "$LOCK_FILE" 2>/dev/null)"
            if [ "$lock_pid" = "$$" ]; then
                rm -f "$LOCK_FILE"
            fi
        fi
        eval "exec $LOCK_FD>&-"
    }

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
                [ $? != 0 ] && cerr "${RED}[Error]${NC}: a1hub 在哪裡?" && exit 1
            fi
        fi
    fi
fi
