#!/bin/bash
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
myself="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

[ ! -f "$jb/usr/local/bin/a1ctl" ] && ln -sf $myself "$jb/usr/local/bin/a1ctl"
[ ! -f "$jb/usr/local/bin/a1mod" ] && ln -sf $myself "$jb/usr/local/bin/a1mod"
[ ! -f "$jb/usr/local/bin/a1" ] && ln -sf $myself "$jb/usr/local/bin/a1"
[ ! -f "$jb/usr/local/bin/a1pm" ] && ln -sf $myself "$jb/usr/local/bin/a1pm"

case "$0" in
    *a1ctl)
       # exec ./cxxa1ctl "$@"
        exec "$jb_a1/bin/cxxa1ctl" "$@"
        ;;
    *a1mod)
       # exec ./cxxa1mod "$@"
        exec "$jb_a1/bin/cxxa1mod" "$@"
        ;;
    *a1)
       # exec ./cxxa1
        exec "$jb_a1/bin/cxxa1"
        ;;
    *a1pm)
       # exec ./cxxa1pm "$@"
        exec "$jb_a1/bin/cxxa1pm" "$@"
    *)
        printf "%s\n" "$0: please run a1 or a1ctl or a1mod or a1pm, not $jb_a1/bin/a1cil"
esac
