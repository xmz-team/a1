// cxxa1pm.cc

#include <string>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/a1pmcore.hpp>
#include <a1/core/lock.hpp>

std::string help_text(const std::string& myself) {
    return std::string(R"(Usage: )" + myself + " <command> [options]") + R"(
command:
  add-repo <url>        Add a remote warehouse
  remove-repo <url>     Delete the remote warehouse
  list                  List all warehouses
  update                Synchronized warehouse index
  search <package id>   Search for remote packages
  info <package id>     Display the details of the remote package
  install <package id>  Install the package from the remote end
  remove <package id>   Remove the module
  upgrade [package id]  Upgrade module
  upgrade-full          Upgrade all modules
  check-update          Check for available updates
  help                  Show this help message
  version               Display the version number
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
    a1pm::config cfg;
    a1::ini::ini_parser pini;

    if (argc < 2) {
        xmz::println(help_text(std::string(argv[0])));
        return 0;
    }

    a1pm::init_repo_list();

    std::string lock_file = cfg.pm_cache + "/lock";
    g_lock_mgr.init(lock_file);
    g_lock_mgr.set_enabled(true);
    if (!g_lock_mgr.acquire()) { return 1; }
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        atexit([]() { g_lock_mgr.release(); });

    std::string cmd = argv[1];

    auto check_opt = [](char *arg) -> bool { if (arg == nullptr) { return false; } return true; };

    if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h" || cmd == "") {
        xmz::println(help_text(std::string(argv[0])));
    } else if (cmd == "add-repo") {
        if (!check_opt(argv[2])) { xmz::log::error("the url cannot be empty."); return 1; }
        a1pm::add_repo(argv[2]);
    } else if (cmd == "remove-repo") {
        if (!check_opt(argv[2])) { xmz::log::error("the url cannot be empty."); return 1; }
        a1pm::remove_repo(argv[2]);
    } else if (cmd == "install") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::install_package(argv[2]);
    } else if (cmd == "remove") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::remove_package(argv[2]);
    } else if (cmd == "list") {
        a1pm::list_repos();
    } else if (cmd == "search") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::search_package(argv[2]);
    } else if (cmd == "info") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::search_package_detail(argv[2]);
    } else if (cmd == "update") {
        a1pm::update_all_repos();
    } else if (cmd == "upgrade") {
        if (!check_opt(argv[2])) { xmz::log::error("the package id cannot be empty."); return 1; }
        a1pm::update_package(argv[2]);
    } else if (cmd == "upgrade-full") {
        a1pm::update_all_packages();

    } else if (cmd == "check-update") {
        a1pm::check_updates();
    } else if (cmd == "version" || cmd == "V") {
        xmz::println("A1PM Version:", a1::_coreapi::a1mod_version);
    } else {
        xmz::log::error("unknown command: ", cmd);
        xmz::log::info("use 'a1pm help' to view help");
        return 1;
    }
    g_lock_mgr.release();
    return 0;
}

