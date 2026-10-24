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

cat > /tmp/io.github.xmz-team.a1.reboot-userspace.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>io.github.xmz-team.a1.reboot-userspace</string>
    <key>ProgramArguments</key>
    <array>
        <string>$jb/usr/bin/sh</string>
        <string>-c</string>
        <string>sleep 5; exec $jb/usr/bin/launchctl reboot userspace</string>
    </array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST

main() {
    if [ ${_lang_is_zh_cn} = true ]; then
        echo "调整来自LF"
        echo "正在为你工作！"
        echo "----------------------------------"
        echo "|作者: LF                         |"
        echo "|维护者: LF, AD, XMZ, amzxus      |"
        echo "|项目: A1                         |"
        echo "|组织(QQ): 1030152896             |"
        echo "----------------------------------"
        echo ""
        echo "设置中..."
    else
        echo "Tweak by LF"
        echo "Sto lavorando per te!"
        echo "----------------------------------"
        echo "|Author: LF                      |"
        echo "|Maintainer: LF, AD, XMZ, amzxus |"
        echo "|Project: A1                     |"
        echo "|Organization(QQ): 1030152896    |"
        echo "----------------------------------"
        echo ""
        echo "setting..."
    fi

    if [ "$1" = "install" ]; then
        chown 0:0 $jb/usr/local/bin/a1cil
        chmod 755 $jb/usr/local/bin/a1cil
        chown 0:0 -R $jb_a1/bin

        [ -f $jb_a1/bin/cxxa1 ]    && chmod 4755 $jb_a1/bin/cxxa1
        [ -f $jb_a1/bin/cxxa1ctl ] && chmod 4755 $jb_a1/bin/cxxa1ctl
        [ -f $jb_a1/bin/cxxa1mod ] && chmod 4755 $jb_a1/bin/cxxa1mod
        [ -f $jb_a1/bin/cxxa1pm ]  && chmod 4755 $jb_a1/bin/cxxa1pm

        ln -sf $jb_a1/bin/bundle $jb/usr/bin/
        ln -sf $jb_a1/bin/bundle_pid $jb/usr/bin/
        ln -sf $jb_a1/bin/pid_bundle $jb/usr/bin/

        ln -sf $jb_a1/bin/flock $jb/usr/bin/
        ln -sf $jb_a1/bin/flock-ios $jb/usr/bin/

        ln -sf $jb_a1/bin/myini $jb/usr/bin/

        if [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
            [ -d "/rootfs" ] && cd /rootfs/var
            [ ! -d "jb" ] && ln -s / ./jb
            ls -l /rootfs/var/jb
            cd "$jb"
            cd var && ln -sf "$(jbroot)/a1"
            cd "$jb_a1"
            touch .type_is_roothide
            cd bin && ln -sf "$(jbroot)" .jbroot
            cd $orig_path
        elif [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
            cd $jb_a1
            touch .type_is_rootless
            cd $orig_path
        elif [ "$(dpkg --print-architecture)" = "iphoneos-arm" ]; then
            cd $jb_a1
            touch .type_is_rootful
            cd $orig_path
        else
            if [ ${_lang_is_zh_cn} = true ]; then
                r=$(uialert -b "我们无法确定你的越狱" -p "点击输入你的越狱" -s "放弃安装" "警告: 未知的越狱" >/dev/null 2>&1);
            else
                r=$(uialert -b "We can't be sure of your jailbreak" -p "enter your jailbreak" -s "uninstall" "Warning: Unknown Prison Break" >/dev/null 2>&1);
            fi

            case ${r} in
                0)
                    if [ ${_lang_is_zh_cn} = true ]; then
                        jb_type=$(uialert -b "请输入你的越狱" "提示:
  无根越狱是iphoneos-arm64
  隐根越狱是iphoneos-arm64e
  有根越狱是iphoneos-arm" -i '' "请输入" | sed -n '1p');
                    else
                        jb_type=$(uialert -b "Please enter your jailbreak" "Tip:
  rootless jailbreak is iphoneos-arm64
  roothide jailbreak is iphoneos-arm64e
  rootful jailbreak is iphoneos-arm" -i '' "Enter" | sed -n '1p');
                    fi

                    if [ ${jb_type} = "iphoneos-arm64" ]; then
                        cd $jb_a1
                        touch .type_is_rootless
                        cd $orig_path
                    elif [ ${jb_type} = "iphoneos-arm64e" ]; then
                        cd $jb_a1
                        touch .type_is_roothide
                        cd $orig_path
                    elif [ ${jb_type} = "iphoneos-arm" ]; then
                        cd $jb_a1
                        touch .type_is_rootful
                        cd $orig_path
                    else
                        cd $jb_a1
                        touch .type_is_unknown
                        cd $orig_path
                    fi
                    ;;
                1) exit 1; ;;
            esac
            unset r;
        fi

        if [ ${_lang_is_zh_cn} = true ]; then
            echo "A1安装完成"
            echo "开始享受!"
        else
            echo "A1 install done."
            echo "Enjoy!"
        fi

        if [ ${_lang_is_zh_cn} = true ]; then
            r=$(uialert -b "设置你的A1
提示: A1的默认配置没有启动任何模式, 如果你需要请点击“开始设置”, 否则A1只会执行一次而不会常驻后台" -p "开始设置" -s "使用默认配置" "设置")
        else
            r=$(uialert -b "Set your A1
Tip: The default configuration of A1 does not start any mode. If you need it, please click 'Start Settings', otherwise A1 will only be executed once and will not stay in the background." -p "Start setting" -s "Use default confign" "Setting")
        fi

        case ${r} in
            0)
                if [ ${_lang_is_zh_cn} = true ]; then
                    r1=$(uialert -b "请选择你的配置
提示:
  Scheduled Guard模式, 每15秒轮询
  Auto Adjust, 每1秒轮询
  Loop, 重复执行" -p "Scheduled Guard" -s "Auto Adjust" -t "Loop" "设置");
                else
                    r1=$(uialert -b "Please select your configuration
Tip:
  Scheduled Guard mode, poll every 15 seconds
  Auto Adjust, poll every 1 second
  Loop, repeat execution" -p "Scheduled Guard" -s "Auto Adjust" -t "Loop" "Setting");
                fi
                case ${r1} in
                    0) a1ctl scheduled-guard on; ;;
                    1) a1ctl auto-adjust on;     ;;
                    2) a1ctl loop on;            ;;
                esac
                ;;
            1) echo ""; ;;
        esac
        unset r r1;
        touch ${instfile}
    elif [ "$1" = "update" ]; then
        rm -rf ${jb_a1}/configs && cp -r ${temp_d}/configs ${jb_a1}
        rm -rf ${jb_a1}/modules && cp -r ${temp_d}/modules ${jb_a1}

        awk '!seen[$0]++' ${temp_d}/high_priority.list ${jb_a1}/high_priority.list > ${jb_a1}/high_priority.list
        awk '!seen[$0]++' ${temp_d}/low_priority.list ${jb_a1}/low_priority.list > ${jb_a1}/low_priority.list
        awk '!seen[$0]++' ${temp_d}/custom_priority.list ${jb_a1}/custom_priority.list > ${jb_a1}/custom_priority.list

        rm -f ${temp_f}
        rm -rf ${temp_d}
    fi
}

case $1 in
    configure)
        if [ -n "$2" ]; then
            if [ -f ${instfile} ]; then
                main install
            else
                main update
            fi
        else
            main install
        fi
        ;;
esac

if [ ${_lang_is_zh_cn} = true ]; then
    r=$(uialert -p "确定" -s "取消" "是否重启用户空间?");
else
    r=$(uialert -p "YES" -s "NO" "reboot userspace?");
fi

case ${r} in
    0)
        launchctl unload /tmp/io.github.xmz-team.a1.reboot-userspace.plist
        launchctl load /tmp/io.github.xmz-team.a1.reboot-userspace.plist
        exit 0;
        ;;
    1)
        rm -f /tmp/io.github.xmz-team.a1.reboot-userspace.plist
        exit 0;
        ;;
esac

