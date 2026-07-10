#!/bin/sh -

rm -f a1-rl a1-rh

c++ -fobjc-arc \
    -D__rootless__ \
    -framework UIKit \
    -framework Foundation \
    -framework OpenGLES \
    -framework CoreGraphics \
    -framework QuartzCore \
    a1c.mm \
    -o a1-rl && ldid -S../../a1c.ens.xml -Hsha1 -Hsha256 -M a1-rl && sudo chown 0:0 a1-rl && sudo chmod 6755 a1-rl

c++ -fobjc-arc \
    -D__roothide__ \
    -framework UIKit \
    -framework Foundation \
    -framework OpenGLES \
    -framework CoreGraphics \
    -framework QuartzCore \
    -L/var/jb/usr/lib/libroothide -lroothide \
    a1c.mm \
    -o a1-rh && ldid -S../../a1c.ens.xml -Hsha1 -Hsha256 -M a1-rh && sudo chown 0:0 a1-rh && sudo chmod 6755 a1-rh
