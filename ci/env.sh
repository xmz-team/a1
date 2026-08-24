if [ "$(dpkg --print-architecture)" = "iphoneos-arm64" ]; then
    jb="/var/jb"
else
    if [ "$(dpkg --print-architecture)" = "iphoneos-arm64e" ]; then
        jb="$(jbroot)"
    else
        jb=""
    fi
fi

if [ "${jb}" = "" ]; then
    SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
    CXXFLAGS1="-arch arm64 -arch arm64e -target arm64-apple-ios14.0 -isysroot ${SDKROOT} -stdlib=libc++"
fi

CXXFLAGS="$CXXFLAGS1 -framework Foundation -framework Security -I. -Isrc/cxxa1 -Isrc/bin/bundle -Isrc/bin -Ilibs/sol2/include -Ilibs/lua -I${jb}/usr/include -I${jb}/usr/local/include"

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

src_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../src/cxxa1"

