#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <a1/core/mod/a1mod_luarun.hpp>

a1mod::luatime lt;

int main() {
    lt.init();
    lt.run_file(std::string(xmz::fs::pwd() + "/test.lua").c_str());
    xmz::println("path:", xmz::fs::pwd());
    return 0;
}
