# loadenv.sh
# Provide A1 environment loading api
_a1_init_env() {
    # load profile
    if [ -f '/etc/profile' ]; then
        source /etc/profile
    elif [ -f '/var/jb/etc/profile' ]; then
        source /var/jb/etc/profile
    else
        echo 'Where the fuck "profile"?' 1>&2
    fi
    # check jb path
    if [ "$(dpkg --print-architecture 2>/dev/null)" = "iphoneos-arm64" ]; then
        jb="/var/jb"
    else
        jb=""
    fi
    export jb
    # A1 dir
    jb_a1="$jb/a1"
    export jb_a1
    # load auth conf
    if [ -n "$jb_a1" ]; then
        if [ -f "$jb_a1/autofonf.ini" ]; then
            source "$jb_a1/autofonf.ini"
        elif [ -f "$jb_a1/a1_ADautoconf.sh" ]; then
            source "$jb_a1/a1_ADautoconf.sh"
            [ -f "$jb_a1/autofonf.ini" ] && source "$jb_a1/autofonf.ini"
        fi
    fi
    # load main conf
    if [ -f "$jb_a1/config.conf" ]; then
        source "$jb_a1/config.conf"
    fi
    if [ -f "$jb_a1/inside.ini" ]; then
        source "$jb_a1/inside.ini"
    fi
}

export -f _a1_init_env

