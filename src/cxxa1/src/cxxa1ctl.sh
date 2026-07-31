#!/bin/sh
set -x # debug
jbdpkgarch="$(dpkg --print-architecture)"
if test "$jbdpkgarch" = "iphoneos-arm64"; then
    jb="/var/jb"
else
    unset jb
    if test "$jbdpkgarch" = "iphoneos-arm64e"; then
        jb="$(jbroot)"
    else
        unset jb
        jb=""
    fi
fi
export jb
jb_a1="$jb/a1"
export jb_a1
exec ./cxxa1ctl # test
# exec "$jb_a1/bin/cxxa1ctl"

