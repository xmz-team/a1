// cxxa1mod.cc

#include <string>

#include <libxmz/fs.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

#include <a1/core/mod/a1mod_config.hpp>
#include <a1/core/mod/a1mod_version.hpp>
#include <a1/core/mod/a1mod_depends.hpp>
#include <a1/core/mod/a1mod.hpp>
#include <a1/core/version.hpp>
#include <a1/core/lock.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/config.hpp>

inline std::string help_text(const std::string& myself) {
    return std::string(R"(Usage: )" + myself + " [command] [option]") + R"(
  init                    Initialize the module system
  list                    List all installed modules
  package <dir> <name>    Packaging module
  install <file>          Install the module from the local file
  remove <ModID>          Delete the module
  enable <ModID>          Enable the module
  disable <ModID>         Disable the module
  help                    Show this help message
  version                 Show version message
)";
}

a1ctl::lock_manager g_lock_mgr;
inline void signal_handler(int sig) {
    xmz::log::info("received the signal", sig, "is cleaning up and exiting...");
    g_lock_mgr.release();
    exit(sig);
}

int main(int argc, char *argv[]) {
    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1Mod need set jb env value!");
        xmz::log::info("Use a1mod status, not cxxa1mod");
        return 1;
    }

    a1::config::jb_path g_jb;
    a1mod::config cfg;
    //a1::ini::ini_parser pini;

    if (argc < 2) {
        xmz::println(help_text(std::string(argv[0])));
        return 0;
    }

    //a1ctl::init_config();

    std::string lock_file = g_jb.mod_dir + "/lock";
    g_lock_mgr.init(lock_file);
    g_lock_mgr.set_enabled(true);
    if (!g_lock_mgr.acquire()) { return 1; }
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        atexit([]() { g_lock_mgr.release(); });

    std::string cmd = argv[1];

    if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h" || cmd == "") {
        xmz::println(help_text(std::string(argv[0])));
    } else if (cmd == "init") {
        a1mod::init_system(cfg, g_jb);
    } else if (cmd == "install" || cmd == "i") {
        a1mod::install(argv[2]);
    } else if (cmd == "remove" || cmd == "r") {
        a1mod::remove(argv[2]);
    } else if (cmd == "list" || cmd == "l") {
        a1mod::list_modules();
    } else if (cmd == "enable") {
        a1mod::enable_module(argv[2]);
    } else if (cmd == "disable") {
        a1mod::disable_module(argv[2]);
    } else if (cmd == "package" || cmd == "pack") {
        a1mod::package_module(argv[2], argv[3]);
    } else if (cmd == "version" || cmd == "V") {
        xmz::println("A1Mod Version:", a1::_coreapi::a1mod_version);
    } else {
        xmz::log::error("unknown command: ", cmd);
        xmz::log::info("use 'a1ctl help' to view help");
        return 1;
    }
    g_lock_mgr.release();
    return 0;
}
