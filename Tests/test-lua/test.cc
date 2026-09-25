#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <a1/core/mod/a1mod_luarun.hpp>

a1mod::luatime lt;

int main() {
    if (xmz::aux::is_file("./test.lua") == 0) {
        lt.init();
        lt.run_file(std::string(xmz::fs::pwd() + "/test.lua").c_str());
        //xmz::println("path:", xmz::fs::pwd());
        return 0;
    } else {
        xmz::log::error("test file: ./test.lua not exist");
        return 1;
    }
}
