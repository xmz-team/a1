#!/bin/sh
set -x # debug

jbdpkgarch="$(dpkg --print-architecture)"

if test "$jbdpkgarch" = "iphoneos-arm64"; then
    jb="/var/jb"
elif test "$jbdpkgarch" = "iphoneos-arm64e"; then
    jb="$(jbroot)"
else
    unset jb
    jb=""
fi

export jb
jb_a1="$jb/a1"
export jb_a1

[ ! -f a1ctl ] && ln -sf $0 a1ctl
[ ! -f a1mod ] && ln -sf $0 a1mod
[ ! -f a1 ] && ln -sf $0 a1

case "$0" in
    *a1ctl)
        exec ./cxxa1ctl "$@"
        #exec "$jb_a1/bin/cxxa1ctl" "$@"
        ;;
    *a1mod)
        exec ./cxxa1mod "$@"
        #exec "$jb_a1/bin/cxxa1mod" "$@"
        ;;
    *a1)
        exec ./cxxa1
        #exec "$jb_a1/bin/cxxa1"
        ;;
    *)
        printf "%s\n" "$0: please run a1 or a1ctl or a1mod, not $jb_a1/bin/a1cil"
esac
