#! /bin/bash
# local the most new
# ADautoconf
# 由 AD 開發
####============== 說明 ==============####
# 一個半通用,跨環境的配置生成腳本        #
# 生成一個基礎環境變量配置文件           #
# 適用於 rootful,rootless,roothide 環境  #
####==================================####

if [ -f '/etc/profile' ]; then
    source /etc/profile
elif [ -f '/var/jb/etc/profile' ]; then
    source /var/jb/etc/profile
else
    echo 'Where the fuck "profile"?' 1>&2
fi

sh_dir=$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )

sh_pwd="$sh_dir"

dpkgpath=$(which dpkg)
ios_arm="iphoneos-arm"
ios_arm64="iphoneos-arm64"
ios_arm64e="iphoneos-arm64e"

dpkgarch=$($dpkgpath --print-architecture)

jb=""
JB=""
sys_bin=""
sys_usr=""
jbbin=""
jbusr=""
rootfs=""
ios_aarch=""

if [ $dpkgarch = $ios_arm64 ] || [ $dpkgarch = $ios_arm ]; then
    rootfs=""
else
    rootfs="/rootfs"
fi

if [ $dpkgarch = $ios_arm ]; then
    ios_aarch="arm"
elif [ $dpkgarch = $ios_arm64 ]; then
    ios_aarch="arm64"
elif [ $dpkgarch = $ios_arm64e ]; then
    ios_aarch="arm64e"
fi

if [ -d /var/jb ] && [ "$dpkgarch" = "$ios_arm64" ]; then
    jb="/var/jb"
    JB="$jb"
elif [ -d /rootfs ] || [ "$dpkgarch" = "$ios_arm64e" ]; then
    jb="$(jbroot)"
    JB="$jb"
else
    if [ "$dpkgarch" = "$ios_arm" ]; then
        jb=""
        JB="$jb"
    fi
fi

_jb_conf() {
    jb="$jb"
    JB="$jb"
    if [ "$dpkgarch" = "$ios_arm" ] || 
       [ "$dpkgarch" = "$ios_arm64" ]; then
        sys_bin="$rootfs/bin"
        sys_usr="$rootfs/usr"
        sys_usrbin="$sys_usr/bin"
        sys_usr_bin="$sys_usr_bin"
        sys_sbin="$rootfs/sbin"
        sys_usrsbin="$rootfs/usr/sbin"
        sys_usr_bin="$sys_usrsbin"
    elif [ "$dpkgarch" = "$ios_arm64e" ]; then
        sys_bin="$rootfs/bin"
        sys_usr="$rootfs/usr"
        sys_usrbin="$sys_usr/bin"
        sys_usr_bin="$sys_usr_bin"
        sys_sbin="$rootfs/sbin"
        sys_usrsbin="$rootfs/usr/sbin"
        sys_usr_bin="$sys_usrsbin"
    fi
    ios_aarch="$ios_aarch"
    jbbin="$jb/bin"
    jbusr="$jb/usr"
    jbusrbin="$jbusr/bin"
    jbusrsbin="$jb/usr/sbin"
    jbsbin="$jb/sbin"
    jblocal="$jb/usr/local"
    jblocal_bin="$jblocal/bin"
    jblocalbin="$jblocal_bin"
    rootfs="$rootfs"
}

_generate_config() {
    cat >> "$config_file" << EOF
# 基礎配置
export jb="$jb"
export JB="$jb"
export sys_bin="$rootfs/bin"
export sys_usr="$rootfs/usr"
export sys_usrbin="$sys_usr/bin"
export sys_usr_bin="$sys_usr_bin"
export sys_sbin="$rootfs/sbin"
export sys_usrsbin="$rootfs/usr/sbin"
export sys_usr_bin="$sys_usrsbin"
export jbbin="$jb/bin"
export jbusr="$jb/usr"
export jbusrbin="$jbusr/bin"
export jbusrsbin="$jb/usr/sbin"
export jbsbin="$jb/sbin"
export jblocal="$jb/usr/local"
export jblocal_bin="$jblocal/bin"
export jblocalbin="$jblocal_bin"
export rootfs="$rootfs"
export ios_aarch="$ios_aarch"

EOF
}

if [ -x "$dpkgpath" ]; then
    case "$dpkgarch" in
        "$ios_arm")
            _jb_conf
            ios_aarch="arm"
            ;;
        "$ios_arm64")
            _jb_conf
            ios_aarch="arm64"
            ;;
	"$ios_arm64e")
            _jb_conf
            ios_aarch="arm64e"
            ;;
        *)
            if [ -d "/var/jb" ] && [ "$dpkgarch" = "$ios_arm64" ]; then
                ios_aarch="arm64"
                jb="/var/jb"
                JB="$jb"
            elif [ -d "/rootfs" ] || [ "$dpkgarch" = "$ios_arm64e" ]; then
                ios_aarch="arm64e"
                jb="$(jbroot)"
                JB="$jb"
            fi
            ;;
    esac
else
    if [ -d "/var/jb" ] && [ "$dpkgarch" = "$ios_arm64" ]; then
        ios_aarch="arm64"
        jb="/var/jb"
        JB="$jb"
    elif [ -d "/rootfs" ] || [ "$dpkgarch" = "$ios_arm64e" ]; then
        ios_aarch="arm64e"
        rootfs="/rootfs"
        jb="$(jbroot)"
    else
        ios_aarch="arm"
        jb=""
        JB="$jb"
    fi
fi

: ${sys_bin:="/bin"}
: ${sys_usr:="/usr/bin"}
: ${jbbin:="$jb/bin"}
: ${jbusr:="$jb/usr"}
: ${ios_aarch:="unknown"}

ios_arch="$ios_aarch"

config_file="${1:-$sh_pwd/autofonf.ini}"

auto_conf() {
    _generate_config
}

if test "${BASH_SOURCE[0]}" = "$0"; then
    auto_conf "autofonf.ini"
fi
