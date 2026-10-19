#!/bin/bash

set -o pipefail

jb=""
orig_path=$(pwd)

source /etc/profile || source /var/jb/etc/profile
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
elif [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
    jb="$(jbroot)"
else
    jb=""
fi

if [ "$(dpkg --print-architecture)" = "iphoneos-arm" ]; then
    echo "[Error]: Rootful is not supported"
    exit 1;
fi

chown -R 0:0 "$jb/Applications/a1gui.app/"
chmod 4755 "$jb/Applications/a1gui.app/a1gui"

cd "$jb/Applications/a1gui.app/"
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
    ln -sf "$(jbroot)" ./.jbroot
elif [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    ln -sf "/var/jb" ./.jbroot
fi
cd $orig_path

