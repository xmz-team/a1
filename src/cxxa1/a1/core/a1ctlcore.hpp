// a1ctlcore.hpp
#include <a1/core/a1core.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/set_defaults.hpp>

#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <cstdlib>
#include <stdlib.h>
#include <filesystem>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/time.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
    inline void default_config() {
        a1::config::jb_path g_jb;
        std::string cfg_f = g_jb.a1config + "/config.ini";
        xmz::fs::writefile(a1::coreapi::cfg_text, cfg_f);
    }

    inline void a1_conf() { return default_config(); }

    inline void init_config() {
        a1::config::jb_path g_jb;
        if (xmz::aux::path_exist(g_jb.a1_dir.c_str()) == 1)
            xmz::fs::mkdir(g_jb.a1_dir);

        if (xmz::aux::is_dir(g_jb.a1config.c_str()) == 1)
            xmz::fs::mkdir(g_jb.a1config);

        if (xmz::aux::is_dir(g_jb.bak_d.c_str()) == 1)
            xmz::fs::mkdir(g_jb.bak_d);

        if (xmz::aux::is_file(g_jb.high_f.c_str()) == 1)
            xmz::fs::writefile(a1::coreapi::lists::high, g_jb.high_f);

        if (xmz::aux::is_file(g_jb.low_f.c_str()) == 1) {
            xmz::fs::writefile(a1::coreapi::lists::low, g_jb.low_f);
        }

        if (xmz::aux::is_file(g_jb.custom_f.c_str()) == 1)
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
        if (!xmz::aux::is_file(config_file.c_str())) {
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
            conflicts++;
        }

        if (loop_mode == true && scheduled_guard == true) {
            xmz::log::warn("loop_mode and scheduled_guard cannot be turned on at the same time!");
            conflicts++;
        }

        if (auto_adjust == true && scheduled_guard == true) {
            xmz::log::warn("auto_adjust and scheduled_guard cannot be turned on at the same time!");
            conflicts++;
        }

        if (conflicts != 0) {
            xmz::log::warn("It is recommended to adjust the configuration to prevent conflicts.");
            return 1;
        }

        return 0;
    }

    inline int check_a1_running() { if (a1::bin::bundle_pid("a1") == -1) { return 1; } else { return 0; } }

    inline int check_if_should_run_a1() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;
        if (xmz::aux::is_file(config_file.c_str()) == 0) {
            pini.parse_file(config_file);
            pini.get_bool("", "loop", false);
            pini.get_bool("", "auto_adjust", false);
            pini.get_bool("", "scheduled_guard", false);
            return 0;
        }
        return 1;
    }

    // backstage start up
    inline void start_a1_service() {
        a1::config::jb_path g_jb;
        xmz::log::info("check the configuration...");
        if (check_config_conflict() != 0) {
            xmz::log::error("configuration conflict, startup has stopped");
            return;
        }

        a1::kill_pid();
        sleep(1);

        std::string a1_script;

        if (xmz::aux::is_file((g_jb.jb + "/usr/local/bin/a1").c_str())) {
            a1_script = g_jb.jb + "/usr/local/bin/a1";
        }

        if (a1_script != "") {
            xmz::log::info("pull up A1 service...");
            pid_t pid = fork();
            pid_t pid2 = 0;
            if (pid == 0) {
                pid2 = fork();
                if (pid2 == 0) {
                    execl((g_jb.jb + "/usr/local/bin/a1").c_str(), nullptr, nullptr, nullptr);
                    _exit(127);
                }
                _exit(0);
            } else if (pid > 0) {
                waitpid(pid, nullptr, 0);
            }
            
            sleep(2);
            if (kill(pid2, 0) == 0) {
                xmz::log::info("A1 has been activated(PID:", pid2, ")");
            } else {
                xmz::log::error("A1 startup failed");
            }
        }
    }

    inline void auto_apply_check() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;
        bool auto_apply = false;
        bool loop = false;
        bool auto_adjust = false;
        bool scheduled_guard = false;

        if (xmz::aux::is_file(config_file.c_str()) == 0) {
            pini.parse_file(config_file);
            auto_apply = pini.get_bool("", "auto_apply", false);
            loop = pini.get_bool("", "loop", false);
            auto_adjust = pini.get_bool("", "auto_adjust", false);
            scheduled_guard = pini.get_bool("", "scheduled_guard", false);
        }

        if (auto_apply == true) {
            if (check_config_conflict() == 1) {
                xmz::log::error("configuration conflict, automatic application has stopped");
                return;
            } else {
                xmz::log::info("automatic application is taking effect...");
                a1::kill_pid();
                sleep(2);
            }
        }

        if (loop == true || auto_adjust == true || scheduled_guard == true) {
            start_a1_service();
        } else {
            xmz::log::warn("A1 is not started");
        }
    }

    inline void check_status() {
        a1::config::jb_path g_jb;
        std::string config_file = g_jb.a1config + "/config.ini";
        a1::ini::ini_parser pini;

        if (check_a1_running() == 0) {
            xmz::log::info("A1 is running");
            if (xmz::aux::is_file(config_file.c_str()) == 0) {
                pini.parse_file(config_file);
                bool loop = pini.get_bool("", "loop", false);
                bool log_reincarnation = pini.get_bool("", "log_reincarnation", false);
                bool custom_priority_enabled = pini.get_bool("", "custom_priority_enabled", false);
                bool auto_apply = pini.get_bool("", "auto_apply", false);
                bool auto_adjust = pini.get_bool("", "auto_adjust", false);
                bool scheduled_guard = pini.get_bool("", "scheduled_guard", false);
                bool module_switch = pini.get_bool("", "module_switch", false);

                bool compat_mode = pini.get_bool("", "compat_mode", false);
                bool lock_use = pini.get_bool("", "lock_use", false);

                auto auxoutcfg = [&](const std::string& name, bool configs = false) -> std::string {
                    if (configs == false) {
                        std::string outcfg = name + " is turned off";
                        return outcfg;
                    } else {
                        std::string outcfg = name + " is turned on";
                        return outcfg;
                    }
                };

                xmz::println("configuration status:");
                xmz::println("    ", auxoutcfg("loop", loop));
                xmz::println("    ", auxoutcfg("auto_adjust", auto_adjust));
                xmz::println("    ", auxoutcfg("scheduled_guard", scheduled_guard));
                xmz::println("    ", auxoutcfg("log_reincarnation", log_reincarnation));
                xmz::println("    ", auxoutcfg("auto_apply", auto_apply));
                xmz::println("    ", auxoutcfg("custom_priority_enabled", custom_priority_enabled));
                xmz::println("    ", auxoutcfg("module_switch", module_switch));
                xmz::println("    ", auxoutcfg("compat_mode", compat_mode));
                xmz::println("    ", auxoutcfg("lock_use", lock_use));
                check_config_conflict();
            }
        } else {
            xmz::log::warn("A1 is not running");
        }
    }

    inline int start_a1() {
        a1::config::jb_path g_jb;
        xmz::println("Start A1 optimization...");
        if (check_a1_running() == 0) {
            xmz::println("A1 is already running.");
            xmz::println("use 'a1ctl restart' to restart A1");
            return 0;
        }

        a1::kill_pid();
        sleep(2);
        start_a1_service();
        sleep(1);

        int pid = a1::bin::bundle_pid("a1");
        std::string cxxa1_path = g_jb.a1_dir + "/bin/cxxa1";

        if (pid != -1) {
            xmz::log::info("A1 has been activated(PID:", pid, ")");
            return 0;
        } else {
            xmz::log::error("A1 Startup failed, try the backup startup method...");
            pid_t pid2 = fork();
            if (pid2 == 0) {
                if (std::getenv("jb") != nullptr) {
                    execl(cxxa1_path.c_str(), nullptr, nullptr);
                } else {
                    setenv("jb", g_jb.jb.c_str(), 1);
                    execl(cxxa1_path.c_str(), nullptr, nullptr);
                }
            }

            sleep(1);
            if (a1::bin::bundle_pid("a1") != -1) {
                xmz::log::info("A1 has been activated(PID:", pid2, ")");
                return 0;
            } else {
                xmz::log::error("A1 failed to start!");
                return 1;
            }
        }
        return 1;
    }

    inline void start_a1_foreground() {
        a1::config::jb_path g_jb;
        std::string a1_script = g_jb.jb + "/usr/local/bin/a1";
        xmz::log::info("Start A1 optimization (foreground mode)...");
        a1::kill_pid();
        sleep(1);
        xmz::println("_______________________________________________");
        if (xmz::aux::is_file(a1_script.c_str())) {
            execl(a1_script.c_str(), nullptr, nullptr);
        } else {
            xmz::log::error("Unable to find A1 script", a1_script);
        }
    }

    inline void update_config(const std::string& key_name, bool value = false) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_dir(g_jb.a1_dir.c_str()) == 1) { xmz::fs::mkdir(g_jb.a1_dir); }
        if (xmz::aux::is_file(config_file.c_str()) == 1) { a1_conf(); }
        pini.parse_file(config_file);
        pini.set("", key_name, value ? "true" : "false");
        xmz::log::info("the configuration has been updated:", key_name, "=", value);
    }

    inline void update_config_int(const std::string& key_name, int value) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_dir(g_jb.a1_dir.c_str()) == 1) { xmz::fs::mkdir(g_jb.a1_dir); }
        if (xmz::aux::is_file(config_file.c_str()) == 1) { a1_conf(); }
        pini.parse_file(config_file);
        pini.set_int("", key_name, value);
        xmz::log::info("the configuration has been updated:", key_name, "=", value);
    }

    inline void set_auto_apply(const bool *opt = nullptr) {
        if (opt == nullptr) {
            xmz::log::error("set_auto_apply function need opt options");
            return;
        }

        if (*opt == true) {
            update_config("auto_apply", true);
            xmz::log::info("automatic effect has been turned on.");
            auto_apply_check();
        } else {
            update_config("auto_apply", false);
            xmz::log::info("automatic effect has been turned off.");
        }
    }

    inline void show_config() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        std::string config_file = g_jb.a1config + "/config.ini";
        if (xmz::aux::is_file(config_file.c_str()) == 0) {
            xmz::println("Current configuration");
            xmz::println("----------------");
            xmz::println(xmz::fs::readfile_str(config_file));
            xmz::println("----------------");
            pini.parse_file(config_file);
            xmz::println("priority setting:");
            xmz::println("  high priority: renice 20 (jetsam", pini.get_int("", "high_priority", 39), ")");
            xmz::println("  low priority: renice 19 (jetsam", pini.get_int("", "low_priority", 19), ")");
            xmz::println("  launchd: renice 0 (jetsam", pini.get_int("", "high_priority", 20), ")");
            xmz::println("loop settings:");
            xmz::println("  loop sleep:", pini.get_int("", "loop_sleep_interval", 5));
            xmz::println("other settings:");
            xmz::println("  take effect automatically:", pini.get_bool("", "auto_apply", false));
            xmz::println("  real-time automatic adjustment:", pini.get_bool("", "auto_adjust", false));
            xmz::println("  regular guard:", pini.get_bool("", "scheduled_guard", false));
            xmz::println("  sudo password-free mode(all):", pini.get_bool("", "use_sudo_all", false));
            xmz::println("  sudo password-free mode(a1):", pini.get_bool("", "use_sudo_a1", false));
            xmz::println("  sudo password-free mode(a1ctl):", pini.get_bool("", "use_sudo_a1ctl", false));
            xmz::println("  root-free execution a1ctl:", pini.get_bool("", "use_root_a1ctl", false));
            xmz::println("  compatible mode:", pini.get_bool("", "compat_mode", false));
        } else {
            xmz::log::error("the document could not be found:", config_file);
            return;
        }
    }

    inline void add_priority(const std::string& priority_opt, const std::string& process_name, int priority_value = -255) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;

        if (priority_opt == "high" || priority_opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f.c_str())) {
                if (xmz::fs::findstr(g_jb.high_f, process_name) == false) {
                    xmz::fs::writefile(process_name, g_jb.high_f);
                    xmz::log::info(process_name, "has been added to the high priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "already exists in the high-priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.high_f, "not exist!");
            }
        } else if (priority_opt == "low" || priority_opt == "l") {
            if (xmz::aux::is_file(g_jb.low_f.c_str())) {
                if (xmz::fs::findstr(g_jb.low_f, process_name) == false) {
                    xmz::fs::writefile(process_name, g_jb.low_f);
                    xmz::log::info(process_name, "has been added to the low priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "already exists in the low-priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.low_f, "not exist!");
            }
        } else if (priority_opt == "custom" || priority_opt == "c") {
            if (xmz::aux::is_file(g_jb.custom_f.c_str())) {
                if (xmz::fs::findstr(g_jb.custom_f, process_name) == false) {
                    if (priority_value != -255 && priority_value >= 0 && priority_value < 100) {
                        pini.set("", process_name, std::to_string(priority_value));
                        xmz::log::info(process_name, "has been added to the custom priority list");
                        auto_apply_check();
                    } else {
                        xmz::log::error("priority_value need >= 0 < 100!");
                    }
                } else {
                    xmz::log::warn("process:", process_name, "already exists in the custom-priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.custom_f, "not exist!");
            }
        } else {
            xmz::log::error("unknown parameters:", priority_opt);
            return;
        }
    }

    inline void remove_priority(const std::string& priority_opt, const std::string& process_name, int priority_value = -255) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;

        if (priority_opt == "high" || priority_opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f.c_str())) {
                if (xmz::fs::findstr(g_jb.high_f, process_name) == true) {
                    xmz::fs::rmfilestr(g_jb.high_f, process_name);
                    xmz::log::info(process_name, "has been removed from the high priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "failed to delete from the high priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.high_f, "not exist!");
            }
        } else if (priority_opt == "low" || priority_opt == "l") {
            if (xmz::aux::is_file(g_jb.low_f.c_str())) {
                if (xmz::fs::findstr(g_jb.low_f, process_name) == true) {
                    xmz::fs::rmfilestr(g_jb.low_f, process_name);
                    xmz::log::info(process_name, "has been removed from the low priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "failed to delete from the low priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.low_f, "not exist!");
            }
        } else if (priority_opt == "custom" || priority_opt == "c") {
            if (xmz::aux::is_file(g_jb.custom_f.c_str())) {
                if (xmz::fs::findstr(g_jb.custom_f, process_name) == true) {
                    pini.rmkey("", process_name);
                    xmz::log::info(process_name, "has been removed from the custom priority list");
                    auto_apply_check();
                } else {
                    xmz::log::warn("process:", process_name, "failed to delete from the custom priority list");
                }
            } else {
                xmz::log::error("file:", g_jb.custom_f, "not exist!");
            }
        } else {
            xmz::log::error("unknown parameters:", priority_opt);
            return;
        }
    }

    inline void list_priority(const std::string& opt) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        if (opt == "high" || opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f.c_str())) {
                xmz::println("high priority list");
                xmz::fs::readfile(g_jb.high_f);
            } else {
                xmz::log::error("the high priority list does not exist");
            }
        } else if (opt == "low" || opt == "l") {
            if (xmz::aux::is_file(g_jb.low_f.c_str())) {
                xmz::println("low priority list");
                xmz::fs::readfile(g_jb.low_f);
            } else {
                xmz::log::error("the low priority list does not exist");
            }
        } else if (opt == "custom" || opt == "c") {
            if (xmz::aux::is_file(g_jb.custom_f.c_str())) {
                xmz::println("custom priority list");
                xmz::fs::readfile(g_jb.custom_f);
            } else {
                xmz::log::error("the custom priority list does not exist.");
            }
        } else {
            xmz::log::error("undefined options:", opt);
            return;
        }
    }

    inline void clear_priority(const std::string& opt) {
        a1::config::jb_path g_jb;
        auto empty = [&](const std::string& name) -> void {
            std::string display_name = name;
            if (name == "h") { display_name = "high"; } 
            else if (name == "l") { display_name = "low"; } 
            else if (name == "c") { display_name = "custom"; }
            xmz::fs::emptyfile(g_jb.high_f);
            xmz::log::info("the", display_name, "priority list has been cleared");
            auto_apply_check();
        };
        if (opt == "high" || opt == "h") {
            empty("high");
        } else if (opt == "low" || opt == "l") {
            empty("low");
        } else if (opt == "custom" || opt == "c") {
            empty("custom");
            xmz::fs::writefile({
                "#custom priority format: process_name = value\n",
                "#value range: 0-99 (Jetsam 0 = Nice -20, Jetsam 39 = Nice 19)\n",
                "#eample: com.apple.springboard = 0\n"
            }, g_jb.custom_f);
        } else {
            xmz::log::error("undefined options:", opt);
            return;
        }
    }

    inline void compat_mode(const bool *opt = nullptr) {
        using xmz::aux::parselink;
        a1::config::jb_path g_jb;
        if (opt != nullptr && *opt == true) {
            update_config("compat_mode", true);
            const char* jbdpkgarch_cstr = std::getenv("jbdpkgarch");
            std::string jbdpkgarch = jbdpkgarch_cstr ? jbdpkgarch_cstr : "";
            if (jbdpkgarch == "iphoneos-arm64e") {
                if (xmz::aux::path_exist(parselink(g_jb.jb).c_str()) == 1) return;
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/var/jb").c_str()) == 1) { xmz::fs::mklndir(g_jb.jb, g_jb.jb + "/var/jb"); }
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/var/a1").c_str()) == 1) { xmz::fs::mklndir(g_jb.a1_dir, g_jb.jb + "/var/"); }
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/rootfs").c_str()) == 0) { if (xmz::aux::path_exist(parselink(g_jb.jb + "/rootfs/var/a1").c_str()) == 1) { xmz::fs::mklndir(g_jb.a1_dir, g_jb.jb + "/rootfs/var/a1"); } }
            } else {
                return;
            }
        } else if (opt != nullptr && *opt == false) {
            update_config("compat_mode", false);
            xmz::log::info("the compatibility mode is turned off");
        }
    }

    inline int set_priority_value(const std::string& priority_type, int value = -255) {
        if (priority_type == "") {
            xmz::log::error("priority_type cannot be empty, priority_type need high|low|launchd");
            return 1;
        }

        if (value != -255 && value >= 0 && value <= 39) {
            if (priority_type == "high" || priority_type == "h") {
                update_config_int("high_priority", value);
            } else if (priority_type == "low" || priority_type == "l") {
                update_config_int("low_priority", value);
            } else if (priority_type == "launchd" || priority_type == "lchd") {
                update_config_int("launchd_priority", value);
            } else {
                xmz::log::error("undefined options:", priority_type);
                xmz::log::error("priority_type cannot be empty, priority_type need high|low|launchd");
                return 1;
            }
        } else {
            xmz::log::error("value must be between 0 and 39");
            return 1;
        }
        return 0;
    }

} /* namespace a1ctl */
