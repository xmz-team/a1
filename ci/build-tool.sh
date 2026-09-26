#build-tool.sh
build_tool() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    local CXXFLAGS2="-I.. -I../.. -I. -I../../cxxa1"
    source "${script_path}/env.sh"
    cd ${script_path}/../src/bin
    cd bundle
    clang++ $CXXFLAGS bundle.mm -o bundle && sign bin bundle && mv bundle ../../../
    cd ../flock-ios
    clang++ $CXXFLAGS flock.cc -o flock && sign bin flock && mv flock ../../../
    cd ../myini
    clang++ $CXXFLAGS myini.cc -o myini && sign bin myini && mv myini ../../../
    cd "${script_path}/../"
}
