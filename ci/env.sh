#env.sh
if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
elif [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
    jb="$(jbroot)"
else
    jb=""
fi

if [ -z "$jb" ] && [ $(uname -s) = "Darwin" ]; then
    SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
    if [ -z "$SDKROOT" ]; then
        mkdir -p "$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"/../tmp && cd "$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"/../tmp && wget "https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz"
        tar xvf *.tar.xz
        cd "$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"/..
        SDKROOT="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)/../tmp/iPhoneOS16.5.sdk"
    fi
    _CXXFLAGS1="-isysroot ${SDKROOT} -stdlib=libc++"
fi

src_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)/../src/cxxa1"

lib_path=(
    -Wl,-rpath,/usr/lib
    -Wl,-rpath,/lib
    -Wl,-rpath,/usr/local/lib
    -Wl,-rpath,/var/jb/usr/lib
    -Wl,-rpath,/var/jb/lib
    -Wl,-rpath,/var/jb/usr/local/lib
    -Wl,-rpath,@loader_path/.jbroot/usr/local/lib
    -Wl,-rpath,@loader_path/.jbroot/usr/lib
    -Wl,-rpath,@loader_path/.jbroot/lib
)

CXXFLAGS="$_CXXFLAGS1 -target arm64-apple-ios14.0 -framework Foundation -framework Security -I${src_path} -I. -Isrc/cxxa1 -Isrc/bin/bundle -Isrc/bin -Ilibs/sol2/include -Ilibs/lua -I${jb}/usr/include -I${src_path}/../bin/bundle -I${src_path}/../.. -I${jb}/usr/local/include ${lib_path[@]} $CXXFLAGS2"

sign() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    local SIGN_OPT1="-Hsha1 -Hsha256 -M"
    if [ "$1" = "bin" ]; then
        local SIGN_OPT="-S${script_path}/../a1.bin.ens.xml $SIGN_OPT1"
    elif [ "$1" = "gui" ]; then
        local SIGN_OPT="-S${script_path}/../a1c.ens.xml $SIGN_OPT1"
    else
        echo "[Error]: unsupported parameters: $1" >&2
        return 1;
    fi
    [ -z "$2" ] && echo "[Error]: the name of the document that needs to be signed" >&2 && return 1;
    ldid ${SIGN_OPT} "$2"
}

general_version="2.0.0-beta2+debug2"
