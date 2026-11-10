// cxxa1.cc
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/time.hpp>

#include <src/bin/ui/uialert.hpp>
#include <a1/core/a1core.hpp>
#include <a1/core/a1aux.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/config.hpp>
#include <a1/core/set_defaults.hpp>
#include <a1/core/mod/lua/a1mod_luarun.hpp>
#include <a1/core/version.hpp>

#include <string>
#include <csignal>
#include <ctime>
#include <iostream>
#include <fstream>
#include <vector>
#include <algorithm>

// load mod
void load_modules(a1mod::luatime& lt) {
    a1::config::jb_path g_jb;
    a1::ini::ini_parser pini;
    struct modinfo {
        std::string section;
        std::string status;
        std::string path;
    };
    auto getmod = [&]() -> std::vector<modinfo> {
        std::string filepath = g_jb.mod_dir + "/module.db.ini";
        std::vector<modinfo> result;
        if (!pini.parse_file(filepath)) { return result; }
        auto sections = pini.get_sec();
        for (const auto& section : sections) {
            modinfo info;
            info.section = section;
            info.status = pini.get(section, "status", "");
            info.path = pini.get(section, "path", "");
            if (!info.status.empty() && !info.path.empty()) { result.push_back(info); }
        }
        return result;
    };
    std::vector<modinfo> modules = getmod();
    if (modules.empty()) {
        xmz::log::info("No modules found to load");
        return;
    }
    for (const auto& mod : modules) {
        if (mod.status == "enabled") {
            if (xmz::aux::is_file(mod.path + "/main.lua")) {
                lt.run_file(mod.path + "/main.lua");
                xmz::log::info("Module:", mod.section, "run successfully");
            } else {
                xmz::log::warn("Module:", mod.section, "main.lua not found at:", mod.path);
            }
        } else {
            xmz::log::info("Module:", mod.section, "not activated (status:", mod.status, ")");
        }
    }
}

int main() {
    auto exec = [&](const std::string& cmd) -> std::string {
        std::string result;
        char buf[4096];
        FILE* p = popen(cmd.c_str(), "r");
        if (!p) return result;
        while (fgets(buf, sizeof buf, p)) result += buf;
        pclose(p);
        return result;
    };

    if (std::getenv("jb") == nullptr) {
        xmz::log::warn("A1 need set jb env value!");
        xmz::log::info("Use a1 status, not cxxa1!");
        auto get_jb = a1::bin::uialert::input(R"(Set jb env
Tip: Enter rootless/rootfhide/rootful will also get the corresponding path)", "jb env");

        if (get_jb.inputs.empty() || get_jb.inputs.front().empty()) {
            xmz::log::error("The input cannot be empty");
            return 1;
        }

        std::string jb_value;
        if (get_jb.inputs.front() == "roothide")      jb_value = exec("sh -c 'jbroot'");
        else if (get_jb.inputs.front() == "rootless") jb_value = "/var/jb";
        else if (get_jb.inputs.front() == "rootful")  jb_value = "/";
        else                                          jb_value = get_jb.inputs.front();
        xmz::log::info("jb =", jb_value);
        if (setenv("jb", jb_value.c_str(), 1) != 0) { xmz::log::error("setenv() failed"); return 1; }
    }
    a1::init();
    a1::config::jb_path g_jb;
    xmz::log::debug("current uid:", getuid());
    xmz::log::debug("current euid:", geteuid());
    xmz::log::debug("current jb path:", g_jb.jb);
    xmz::log::debug("current a1 path:", g_jb.a1_dir);
    a1mod::luatime lt;
    xmz::println(xmz::get_time_str());
    xmz::println("______________________");
    xmz::println("A1 are working......");
    xmz::println("A1 Version:", a1::version::a1);
    xmz::println("----------------------");
    // Initialize environment, read defaults from environment
    a1::coreapi::set_defaults();
    auto& config = a1::coreapi::set_defaults_cfg();
    // read priority lists
    a1::priority_manager pm;
    pm.read_priority_lists(false);
    // Load modules
    if (config.module_switch == true) {
        lt.init();
        load_modules(lt);
    } else {
        xmz::log::info("the module system is shut down");
    }
    a1::apply_kernel_patches();
    a1::adjust_launchd(config.launchd_priority);
    a1::aux::optimize_system();
    // mode selection
    if (config.auto_adjust) {
        xmz::println("starting Auto-Adjust (real-time) mode...");
        a1::auto_adjust();
    } else if (config.scheduled_guard) {
        xmz::println("starting Scheduled Guard mode...");
        a1::scheduled_guard();
    } else if (config.loop_mode) {
        xmz::println("starting Loop mode...");
        while (true) {
            // countdown display
            for (int i = config.loop_sleep_interval; i >= 1; i--) {
                xmz::print("\rNext Circulate Time:" + std::to_string(i) + "s");
                std::cout.flush();
                sleep(1);
            }
            xmz::println("");
            // reload config
            a1::aux::read_a1_config();
            // check if loop mode is still enabled
            if (!a1::coreapi::set_defaults_cfg().loop_mode) break;
            // re-read priority lists with filter
            pm.read_priority_lists(true);
            xmz::println("Running optimization cycle...");
            a1::aux::optimize_system();
        }
    } else {
        xmz::log::warn("No monitoring mode enabled.");
        return 0;
    }
    xmz::println("All operations completed successfully");
    sleep(1);
    return 0;
}
