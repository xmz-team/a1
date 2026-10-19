#!/bin/bash
set -o pipefail

_lang_is_zh_cn=false
plutil -key 'AppleLanguages' "$([ -e '/rootfs' ] && echo '/rootfs')/var/mobile/Library/Preferences/.GlobalPreferences.plist" | sed -n '2p' | grep -q 'zh-Hans' && _lang_is_zh_cn=true

jb=""
jb_a1=""
orig_path=$(pwd)

source /etc/profile || source /var/jb/etc/profile

if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
elif [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
    jb="$(jbroot)"
else
    jb=""
fi

jb_a1="$jb/a1"
instfile="${jb_a1}/.installed"
package="io.github.xmz-team.a1"
temp_f="/tmp/${package}-update"
temp_d="${temp_f}.d"
is_rc="/tmp/${package}-is-rc"

case $1 in
    upgrade)
        cp -aR ${jb_a1}/configs ${temp_d}/
        cp -ar ${jb_a1}/modules ${temp_d}/
        cp -ar ${jb_a1}/*.list  ${temp_d}/
        touch ${temp_f}
        ;;
esac
