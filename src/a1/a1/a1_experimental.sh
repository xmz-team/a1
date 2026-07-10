#!/bin/bash

: '

Created by AD on 6/12/25
Copyright (c) 2025 AD All rights reserved.

'

if [ -f '/etc/profile' ]; then
    source /etc/profile
elif [ -f '/var/jb/etc/profile' ]; then
    source /var/jb/etc/profile
else
    echo 'Where the fuck "profile"?' 1>&2
fi

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

$jb/usr/sbin/sysctl kern.vm_page_free_min=20000
$jb/usr/sbin/sysctl kern.vm_page_free_reserved=256
$jb/usr/sbin/sysctl kern.memorystatus_kill_on_sustained_pressure_delay_ms=86400000
$jb/usr/sbin/sysctl kern.vm_max_delayed_work_limit=64