#!/bin/bash

set -o pipefail

jb=""

source /etc/profile || source /var/jb/etc/profile
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
elif [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
    jb="$(jbroot)"
else
    jb=""
fi

rm -f $jb/Applications/a1gui.app/.jbroot
