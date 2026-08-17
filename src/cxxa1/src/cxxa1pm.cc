// cxxa1pm.cc

#include <string>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/a1pmcore.hpp>
#include <a1/core/a1ctlcore.hpp>

std::string help_text(const std::string& myself) {
    return std::string(R"(Usage: )" + myself + " <command> [options]" + R"(
command:
  add-repo <url>			添加远端仓库
  remove-repo <url>			删除远端仓库
  list					列出所有仓库
  update					同步仓库索引
  search <package id>		搜索远端包
  info <package id>			显示远端包详细信息
  install <package id>		从远端安装包
  remove <package id>      移除模塊
  upgrade [package id]		升级模块
  upgrade-full				升级全部模块
  check-update				检查可用更新
  help						显示此帮助信息
  version					显示版本号
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

    if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h" || cmd == "") {
        xmz::println(help_text(std::string(argv[0])));
    } else if (cmd == "add-repo") {
        a1pm::add_repo(argv[2]);
    } else if (cmd == "remove-repo") {
        a1pm::remove_repo(argv[2]);
    } else if (cmd == "install") {
        a1pm::install_package(argv[2]);
    } else if (cmd == "remove") {
        a1pm::remove_package(argv[2]);
    } else if (cmd == "list") {
        a1pm::list_repos();
    } else if (cmd == "") {
        search_package(argv[2]);
    } else if (cmd == "info") {
        search_package_detail(argv[2]);
    } else if (cmd == "update") {
        update_all_repos();
    } else if (cmd == "upgrade") {
        update_package(argv[2]);
    } else if (cmd == "upgrade-full") {
        update_all_packages();

    } else if (cmd == "check-update") {
        check_updates();
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
