#include <a1/core/a1core.hpp>
#include <a1/core/a1ctlcore.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

int main() {
    a1::init();
    if (a1ctl::check_a1_running() == 0) {
        xmz::println("a1 is running");
    } else {
        xmz::log::error("a1 is not running");
    }
    xmz::println("a1 pid is:", a1::bin::bundle_pid("cxxa1"));
    return 0;
}
