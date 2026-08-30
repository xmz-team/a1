#build-tool.sh
build_tool() {
    local script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
    source "${script_path}/env.sh"
    cd ${script_path}/../src/bin
    local CXXFLAGS2="-I.. -I../.. -I. -I../../cxxa1"
    cd bundle
    c++ $CXXFLAGS bundle.mm -o bundle && sign bin bundle && mv bundle ../../../
    cd ../flock-ios
    c++ $CXXFLAGS flock.cc -o flock && sign bin flock && mv flock ../../../
    cd ../myini
    c++ $CXXFLAGS myini.cc -o myini && sign bin myini && mv myini ../../../
    cd "${script_path}/../"
}
