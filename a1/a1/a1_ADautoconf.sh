#! /bin/bash
# a1_ADautoconf
# name: A1 autoconf
# update time: 13:02/27/1/26

if [ -f '/etc/profile' ]; then
    source /etc/profile
elif [ -f '/var/jb/etc/profile' ]; then
    source /var/jb/etc/profile
else
    echo 'Where the fuck "profile"?' 1>&2
fi

sh_dir=$( cd $(dirname ${BASH_SOURCE[0]} ) && pwd )

sh_pwd="$sh_dir"

rm -f "$sh_pwd/autofonf.ini"

source "$sh_pwd/ADautoconf.sh" >/dev/null 2>&1
jb_a1="$jb/a1"

config_file="$sh_pwd/autofonf.ini"

a1_auto_conf() {
    cat >> "$config_file" << EOF
# a1 conf
export ps="$sys_bin/ps"
export jb_a1="$jb_a1"
export a1_expand="$jb_a1/a1.expand"
export jblocal="$jbusr/local"
export a1_exe="$jblocal/bin/a1"
export a1ctl_exe="$jblocal/bin/a1ctl"
export a1hub_exe="$jblocal/bin/a1hub"
export a1_return_exe="$jblocal/bin/a1-return"
export a1_conf="$jb_a1/config.conf"
export a1_inside="$jb_a1/inside.ini"
export jbsbin="$jbusr/sbin"
export jbusrbin="$jbusr/bin"

# a1 module conf
export jq="$jbusrbin/jq"
export zip="$jbusrbin/zip"
export unzip="$jbusr/bin/unzip"
export find="$jbusrbin/find"
export grep="$jbusrbin/grep"
export sed="$jbusrbin/sed"
export mkdir="$jbusrbin/mkdir"
export rm="$jbusrbin/rm"
export mv="$jbusrbin/mv"
export cp="$jbusrbin/cp"
export date="$jbusrbin/date"

# flock
export flock="$jb/opt/a1/bin/flock"

EOF
}

if [ -f "$sh_pwd/autofonf.ini" ]; then
    a1_auto_conf
else
    auto_conf
    a1_auto_conf
fi
