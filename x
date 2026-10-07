#!/bin/bash -e
#x.sh
script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
source ${script_path}/ci/env.sh
source ${script_path}/ci/package.sh
source ${script_path}/ci/build-tool.sh
source ${script_path}/ci/generate-version.sh

b_a1() {
    local lua_patch_file="${script_path}/patchs/loslib_lsystem.patch"
    if [ "$use_lua_cache" = false ]; then
        cd ${script_path}/libs/lua
        cp loslib.c loslib.c.orig
        patch -p0 < ${lua_patch_file}
        make clean
        make CC="$(command -v clang) -target arm64-apple-ios14.0 -miphoneos-version-min=14.0 -isysroot ${SDKROOT} -Wno-unknown-warning-option" a
        rm -f loslib.c && mv loslib.c.orig loslib.c
        cd ${script_path}
        clang++ -ObjC++ \
         $CXXFLAGS \
         ${cxxa1_src_path}/src/cxxa1.cc -o cxxa1 \
         -lm ${script_path}/libs/lua/liblua.a
    else
        if [ ! -f "${script_path}/libs/lua/liblua.a" ]; then
            echo "[Error]: cache: ${script_path}/libs/lua/liblua.a does not exist" && exit 1;
        else
            clang++ -ObjC++ \
             $CXXFLAGS \
             ${cxxa1_src_path}/src/cxxa1.cc -o cxxa1 \
             -lm ${script_path}/libs/lua/liblua.a
        fi
    fi
    sign bin cxxa1
}

b_a1ctl() {
    clang++ -ObjC++ \
     $CXXFLAGS \
     -lzip \
     ${cxxa1_src_path}/src/cxxa1ctl.cc -o cxxa1ctl
    sign bin cxxa1ctl
}

b_a1mod() {
    clang++ -ObjC++ \
     $CXXFLAGS \
     -lzip -lssl -lcrypto \
     ${cxxa1_src_path}/src/cxxa1mod.cc -o cxxa1mod
    sign bin cxxa1mod
}

b_a1pm() {
    clang++ -ObjC++ \
     $CXXFLAGS \
     -lzip -lcurl -lssl -lcrypto \
     ${cxxa1_src_path}/src/cxxa1pm.cc -o cxxa1pm
    sign bin cxxa1pm
}

b_gui() {
    src_gui="${src_path}/gui"
    clang++ -ObjC++ -fobjc-arc \
        $CXXFLAGS \
        -Wno-deprecated-declarations \
        -DA1_USE_GUI_CFG \
        -lzip -lcurl -lssl -lcrypto \
        ${src_gui}/app/*.mm \
        ${src_gui}/ui/Categories/*.mm \
        ${src_gui}/ui/ViewControllers/*.mm \
        ${src_gui}/core/*.mm \
        -o a1gui
    sign gui a1gui
}

show_help() {
    cat >&2 <<EOF
usage: $0 [options] <target> [<target> ...]

options:
  --a1-use-lua-cache      use cached liblua.a
  --is-local-build        skip generate_version
  -h, --help              show this help

targets:
  a1 | a1ctl | a1mod | a1pm | a1gui
  build-a1-all | build-a1 | build-a1-tool
  pack-a1 | pack-a1gui | pack-all
EOF
}

use_lua_cache=false
is_local_build=false
declare -a targets=()

while [ $# -gt 0 ]
do
    case "$1" in
        --a1-use-lua-cache)
            use_lua_cache=true
            shift
            ;;
        --is-local-build)
            is_local_build=true
            shift
            ;;
        -h|--help|"")
            show_help
            exit 1
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do targets+=("$1"); shift; done
            ;;
        -*)
            echo "[Error]: unknown option: $1" >&2
            show_help
            exit 1
            ;;
        *)
            targets+=("$1")
            shift
            ;;
    esac
done

if [ ${#targets[@]} -eq 0 ]; then
    show_help
    exit 1
fi

if [ ! -f "${script_path}/.generate.lock" ]; then
    generate_version general
    touch "${script_path}/.generate.lock"
fi

for target in "${targets[@]}"
do
    case "$target" in
        a1)
            if [ "$is_local_build" = false ]; then
                generate_version a1
            fi
            b_a1 ;;
        a1ctl)
            if [ "$is_local_build" = false ]; then
                generate_version a1ctl
            fi
            b_a1ctl ;;
        a1mod)
            if [ "$is_local_build" = false ]; then
                generate_version a1mod
            fi
            b_a1mod ;;
        a1pm)
            if [ "$is_local_build" = false ]; then
                generate_version a1pm
            fi
            b_a1pm ;;
        a1gui)
            if [ "$is_local_build" = false ]; then
                generate_version gui
            fi
            b_gui ;;
        build-a1-all|build-a1)
            if [ "$is_local_build" = false ]; then
                generate_version all --no-general
            fi
            b_a1; b_a1ctl; b_a1mod; b_a1pm; b_gui ;;
        build-a1-tool) build_tool ;;
        pack-a1)     pack_a1 ;;
        pack-a1gui)  pack_a1gui ;;
        pack-all)    pack_all ;;
        *)
            echo "[Error]: unknown target: $target" >&2
            show_help
            exit 1
            ;;
    esac
done
