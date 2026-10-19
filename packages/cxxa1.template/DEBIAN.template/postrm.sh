#!/bin/bash
set -o pipefail

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

case "$1" in
    remove|purge)
        rm -f $jb/usr/bin/bundle
        rm -f $jb/usr/bin/bundle_pid
        rm -f $jb/usr/bin/pid_bundle

        rm -f $jb/usr/bin/flock
        rm -f $jb/usr/bin/flock-ios
        rm -f $jb/usr/bin/myini

        rm -rf ${jb_a1}/backup
        rm -f ${jb_a1}/.type_is_*
        if [ "$1" = "purge" ]; then
            rm -rf ${jb_a1}/
        fi
        ;;
esac
