#package.sh
pack() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    source "${script_path}/env.sh"
    source "${script_path}/generate-version.sh"
    local time="$(date '+%Y%m%d-%H%M%S')"
    cd "$script_path/../"
    mkdir -p packages/packdeb/$time
    if ls packages/cxxa1/*.deb >/dev/null 2>&1; then
        mv packages/cxxa1/*.deb packages/packdeb/$time/
    fi
    rm -rf packages/cxxa1
    cp -a packages/cxxa1.template packages/cxxa1
    if ls packages/a1gui/*.deb >/dev/null 2>&1; then
        mv packages/a1gui/*.deb packages/packdeb/$time/
    fi
    rm -rf packages/a1gui
    cp -a packages/a1gui.template packages/a1gui
    build_a1() {
        [ -z "$1" ] && echo "[Error]: the parameter cannot be empty" >&2
        cp cxx* packages/cxxa1/$1/$2/a1/bin/
        [ -f myini ] && cp myini packages/cxxa1/$1/$2/a1/bin/ || echo "[Warn]: myini does not exist" >&2
        [ -f flock ] && cp flock packages/cxxa1/$1/$2/a1/bin/ || echo "[Warn]: flock does not exist" >&2
        [ -f bundle ] && cp bundle packages/cxxa1/$1/$2/a1/bin/ || echo "[Warn]: bundle does not exist" >&2
        ln -sf bundle packages/cxxa1/$1/$2/a1/bin/bundle_pid
        ln -sf bundle packages/cxxa1/$1/$2/a1/bin/pid_bundle
        ln -sf flock packages/cxxa1/$1/$2/a1/bin/flock-ios
        echo "Version: ${general_version}" >> packages/cxxa1/$1/DEBIAN/control
        dpkg-deb -b packages/cxxa1/$1 packages/cxxa1/cxxa1-${1}.deb
        dpkg-name packages/cxxa1/cxxa1-${1}.deb
    }
    build_a1gui() {
        [ -z "$1" ] && echo "[Error]: the parameter cannot be empty" >&2
        cp a1gui packages/a1gui/$1/$2/Applications/a1gui.app/
        cp ${script_path}/../src/gui/Info.plist packages/a1gui/$1/$2/Applications/a1gui.app/
        cp -r ${script_path}/../src/gui/resources/* packages/a1gui/$1/$2/Applications/a1gui.app/
        echo "Version: $(get_version gui)" >> packages/a1gui/$1/DEBIAN/control
        dpkg-deb -b packages/a1gui/$1 packages/a1gui/a1gui-${1}.deb
        dpkg-name packages/a1gui/a1gui-${1}.deb
    }
    if [ ! "$1" = "no-pack-a1" ] || [ "$1" = "all" ]; then
        build_a1 rootless "var/jb"
        build_a1 rootful ""
        build_a1 roothide ""
    fi
    if [ ! "$1" = "no-pack-a1gui" ] || [ "$1" = "all" ]; then
        build_a1gui rootless "var/jb"
        build_a1gui roothide ""
    fi
    rm -f cxx* a1gui
    rm -f bundle myini flock
}

pack_a1() { pack "no-pack-a1gui" "$@"; }
pack_a1gui() { pack "no-pack-a1" "$@"; }
pack_all() { pack "all" "$@"; }
