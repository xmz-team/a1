#include <a1/core/a1core.hpp>
#include <a1/core/myini.hpp>

#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <cstdlib>
#include <stdlib.h>
#include <filesystem>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/time.hpp>

namespace a1ctl {
    // origin function name is _a1ctl_a1_conf
    inline void default_config() {
        a1::config::jb_path g_jb;
        std::string cfg_f = g_jb.a1config + "/config.ini";
        xmz::fs::writefile(a1::coreapi::config_text, cfg_f);
    }
    inline void init_config() {
        a1::config::jb_path g_jb;
        if (xmz::aux::path_exist(g_jb.a1_dir) == 1)
            xmz::fs::mkdir(g_jb.a1_dir);

        if (xmz::aux::is_dir(g_jb.a1config) == 1)
            xmz::fs::mkdir(g_jb.a1config);

        if (xmz::aux::is_dir(g_jb.bak_d) == 1)
            xmz::fs::mkdir(g_jb.bak_d);

        if (xmz::aux::is_file(g_jb.high_f) == 1)
            xmz::fs::writefile(a1::coreapi::high, g_jb.high_f);

        if (xmz::aux::is_file(g_jb.low_f) == 1) {
            xmz::fs::writefile(a1::coreapi::low, g_jb.low_f);

        if (xmz::aux::is_file(g_jb.custom_f) == 1)
            xmz::fs::writefile({
                "#custom priority format: process_name = value\n",
                "#value range: 0-99 (Jetsam 0 = Nice -20, Jetsam 39 = Nice 19)\n",
                "#eample: com.apple.springboard = 0\n"
            }, g_jb.custom_f);
    }

    inline int check_config_conflict() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (!xmz::aux::is_file(config_file) {
            xmz::log::warn("file:", config_file, "not exist!");
            xmz::log::warn("The default configuration has been automatically created");
            xmz::fs::writefile(a1::coreapi::cfg_text, config_file);
        }

        if (!pini.parse_file(config_file)) return -1;
        bool loop_mode = pini.get_bool("", "loop", false);
        bool auto_adjust = pini.get_bool("", "auto_adjust", false);
        bool scheduled_guard = pini.get_bool("", "scheduled_guard", false);
        int conflicts = 0;
        if (loop_mode == true && auto_adjust == true) {
            xmz::log::warn("loop_mode and auto_adjust cannot be turned on at the same time!");
            ((conflicts++))
        }

        if (loop_mode == true && scheduled_guard == true) {
            xmz::log::warn("loop_mode and scheduled_guard cannot be turned on at the same time!");
            ((conflicts++))
        }

        if (auto_adjust == true && scheduled_guard == true) {
            xmz::log::warn("auto_adjust and scheduled_guard cannot be turned on at the same time!");
            ((conflicts++))
        }

        if (conflicts != 0) {
            xmz::log::warn("It is recommended to adjust the configuration to prevent conflicts.");
            return 1;
        }

        return 0;
    }

    inline int save_config() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;

        xmz::fs::mkdir(g_jb.bak_d);
        if (xmz::aux::is_dir(g_jb.bak_d) == 1) {
            xmz::log::error("unable to create a backup directory:", g_jb.bak_d);
            return 1;
        }

        bool have_files = false;
        std::string cfg_file = g_jb.a1config + "/config.ini";

        if (xmz::aux::is_file(cfg_file) == 0) have_files = true;
        if (xmz::aux::is_file(g_jb.high_f) == 0) have_files = true;
        if (xmz::aux::is_file(g_jb.low_f) == 0) have_files = true;
        if (xmz::aux::is_file(g_jb.custom_f) == 0) have_files = true;

        if (have_files == false) {
            xmz::log::error("no configuration files were found!");
            return 1;
        }

        std::string temp_dir = "/tmp/a1_" + std::to_string(getpid()) + "_dir";

        xmz::fs::mkdir(temp_dir);

        if (!xmz::aux::is_file(temp_dir)) {
            xmz::log::error("unable to create a temporary directory!");
            return 1;
        }
    
        int copied_count = 0;

        if (xmz::aux::is_file(cfg_file) {
            xmz::fs::cp(xmz::fs::cptype, cfg_file, temp_dir + cfg_file);
            ((copied_count++))
        }

        if (xmz::aux::is_file(g_jb.high_f) {
            xmz::fs::cp(xmz::fs::cptype::file, g_jb.high_f, temp_dir + "/high_priority.list");
            ((copied_count++))
        }
    
        if (xmz::aux::is_file(g_jb.low_f) {
            xmz::fs::cp(xmz::fs::cptype::file, g_jb.low_f, temp_dir + "/low_priority.list");
            ((copied_count++))
        }

        if (xmz::aux::is_file(g_jb.custom_f) {
            xmz::fs::cp(xmz::fs::cptype::file, g_jb.custom_f, temp_dir + "/custom_priority_file");
            ((copied_count++))
        }

        if (copied_count == 0) {
            xmz::fs::recrmdir("temp_dir");
            xmz::log::error("there are no files to back up.")
            return 1;
        }

        std::string timestamp = xmz::get_time_str();
        std::string backup_file = g_jb.bak_d+ "/config_backup_" + timestamp + ".tar.gz";
        std::string orig_path = xmz::fs::pwd();
        if (!xmz::fs::cd(temp_dir)) {
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }

        pid_t pid = fork();
        if (pid == 0) {
            std::string path_env = std::getenv("PATH");
            std::setenv("/var/jb/bin:/var/jb/usr/bin" + ":" + path_env);
            execl("tar", "-czf", backup_file, "--", "*");
            _exit(127);
        } else if (pid > 0) {
            int status;
            waitpid(pid, &status, 0);
            if (WIFEXITED(status)) {
                int exit_code = WEXITSTATUS(status);
                xmz::println("exit code:", exit_code);
            } else if (WIFSIGNALED(status)) {
                int signal = WTERMSIG(status);
                int exit_code = signal;
                xmz::println("be signaled", signal, "terminate");
            }
        }

        //$jb/usr/bin/tar -czf "$backup_file" -- *
        int tar_status = exit_code;
        xmz::fs::cd(orig_path);
        xmz::fs::recrmdid(temp_dir);
        if (tar_status != 0) {
            xmz::log::error("failed to create a backup file");
            xmz::fs::rmfile(backup_file);
            return 1
        }

        std::filesystem::path file_path = backup_file;
        try {
            auto file_size = std::filesystem::file_size(file_path);
            xmz::println("successful configuration backup", file_size, "B");
            xmz::println("bakcup file:", backup_file);
        } catch (const std::filesystem::filesystem_error& e) {
            xmz::log::error(e.what());
        }
    }

    inline int check_a1_running() { if (a1::bin::bundle_pid("a1") == -1 && a1::bin::bundle_pid("a1ctl") == -1) { return 0; } else { return 1; } }

    inline int check_if_should_run_a1() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.conf";
        a1::ini::ini_parser pini;
        if (xmz::aux::is_file(config_file) == 0) {
            pini.parse(config_file);
            pini.get_bool("", "loop", false);
            pini.get_bool("", "auto_adjust", false);
            pini.get_bool("", "scheduled_guard", false);
            return 0;
        }
        return 1;
    }

}
