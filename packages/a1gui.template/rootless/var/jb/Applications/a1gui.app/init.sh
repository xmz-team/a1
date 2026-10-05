if [ -f "/etc/profile" ]; then
    . "/etc/profile"
else
    . "/var/jb/etc/profile"
fi
for arg in $@
do
    case $arg in
        --init|-i)
            printf "${PATH}"
            ;;
        --get-jb-env|-gjb)
            jbenv="$(dpkg --print-architecture)"
            if [ "$jbenv" = "iphoneos-arm64" ]; then
                printf "/var/jb"
            elif [ "$jbenv" = "iphoneos-arm64e" ]; then
                printf "$(jbroot)"
            else
                printf ""
            fi
            ;;
    esac
done
