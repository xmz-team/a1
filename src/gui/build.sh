#!/bin/sh -
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    if [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
        jb="$(jbroot)"
    else
        jb=""
    fi
fi

jub="$jb/usr/bin"
rm="$jub/rm"
CXX="$jub/c++"
ldid="$jub/ldid"
chown="$jub/chown"
chmod="$jub/chmod"

$rm -f a1-rl a1-rh

$CXX -fobjc-arc \
    -D__rootless__ \
    -framework UIKit \
    -framework Foundation \
    -framework OpenGLES \
    -framework CoreGraphics \
    -framework QuartzCore \
    a1c.mm \
    -o a1-rl && $ldid -S../../a1c.ens.xml -Hsha1 -Hsha256 -M a1-rl && sudo $chown 0:0 a1-rl && sudo $chmod 6755 a1-rl

$CXX -fobjc-arc \
    -D__roothide__ \
    -framework UIKit \
    -framework Foundation \
    -framework OpenGLES \
    -framework CoreGraphics \
    -framework QuartzCore \
    -L/var/jb/usr/lib/libroothide -lroothide \
    a1c.mm \
    -o a1-rh && $ldid -S../../a1c.ens.xml -Hsha1 -Hsha256 -M a1-rh && sudo $chown 0:0 a1-rh && sudo $chmod 6755 a1-rh
