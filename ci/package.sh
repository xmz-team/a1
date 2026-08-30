#package.sh
pack() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    source "${script_path}/env.sh"
    local time="$(date '+%Y%m%d-%H%M%S')"
    cd "$script_path/../"
    mkdir -p packages/packdeb/$time
    if ls packages/cxxa1/*.deb >/dev/null 2>&1; then
        mv packages/cxxa1/*.deb packages/packdeb/$time/
    fi
    rm -rf packages/cxxa1
    cp -a packages/cxxa1.template packages/cxxa1
    build() {
        [ -z "$1" ] && echo "[Error]: the parameter cannot be empty"
        echo cxx*
        cp cxx* packages/cxxa1/$1/$2/a1/bin/
        if [ -f myini ]; then
            cp myini packages/cxxa1/$1/$2/a1/bin/
        else
            echo "[Warn]: myini does not exist"
        fi

        if [ -f flock ]; then
            cp flock packages/cxxa1/$1/$2/a1/bin/
        else
            echo "[Warn]: flock does not exist"
        fi

        if [ -f bundle ]; then
            cp bundle packages/cxxa1/$1/$2/a1/bin/
        else
            echo "[Warn]: bundle does not exist"
        fi

        ln -s bundle packages/cxxa1/$1/$2/a1/bin/bundle_pid
        ln -s bundle packages/cxxa1/$1/$2/a1/bin/pid_bundle
        ln -s flock packages/cxxa1/$1/$2/a1/bin/flock-ios
        echo "Version: ${general_version}" >> packages/cxxa1/$1/DEBIAN/control
        dpkg-deb -b packages/cxxa1/$1 packages/cxxa1/cxxa1-${1}.deb
        dpkg-name packages/cxxa1/cxxa1-${1}.deb
    }
    build rootless "var/jb"
    build rootful ""
    build roothide ""
    rm -f cxx*
    rm -f bundle myini flock
}
