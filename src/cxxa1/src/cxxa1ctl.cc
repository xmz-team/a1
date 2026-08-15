// cxxa1ctl.cc
#include <a1/core/a1ctlcore.hpp>
#include <a1/core/version.hpp>
#include <a1/core/lock.hpp>
#include <a1/core/myini.hpp>

#include <libxmz/log.hpp>
#include <libxmz/io.hpp>
#include <string>
#include <cstdlib>
#include <unistd.h>

inline std::string help_text(const std::string& myself) {
    return std::string(R"(
  __    _       _     _     ___  
 / /\  / |     | |_| | | | | |_) 
/_/--\ |_|     |_| | \_\_/ |_|_) 

Author: LF | Maintainer: LF, AD
Organization(QQ): 1030152896
)") + "Usage: " + myself + " [options] [command]" + R"(
Basic Commands:
  start                    Start A1
  stop                     Stop A1
  status                   View status
  restart                  Restart A1

Mode Control:
  loop <on|off>            Enable/disable loop mode
  auto-adjust <on|off>     Enable/disable real-time auto-adjust mode (1s polling)
  scheduled-guard <on|off> Enable/disable scheduled guard mode (15s polling)
  olr <on|off>             Enable/disable log reincarnation
  custom <on|off>          Enable/disable custom priority

Priority Management:
  add high <process>       Add to high priority list
  add low <process>        Add to low priority list
  add <process> <value>    Add custom priority (0-99)
  remove <process>         Remove from priority list
  list <high|low|custom>   View priority list
  clear <high|low|custom>  Clear priority list
  set <type> <value>       Set priority value

  type: high, low, launchd*
  value: 0-39 (Jetsam value)

Configuration Management:
  config                   View current configuration
  set-interval <seconds>   Set optimization interval
  loop-sleep <seconds>     Set loop interval
  auto-apply <on|off>      Enable/disable auto-apply
  restore                  Restore configuration from backup
  compat <on|off>          Enable/disable compatibility mode

Module System: # ModSystem to be supported
  mod <on|off>             Module system switch
  mod init                 Initialize module system
  mod list                 List all modules
  mod pack <directory>     Package module
  mod install <file>       Install module
  mod enable <moduleID>    Enable module
  mod disable <moduleID>   Disable module
  mod load                 Load enabled modules
  mod remove <moduleID>    Remove module

Other:
  help                     Show this help
  version                  Show Version
  -f                       Forced start/foreground mode

Tips:
  Real-time auto-adjust mode: Check new processes every second and adjust priority (more aggressive)
  Scheduled guard mode: Check every 15 seconds (more battery efficient)
  Loop mode: Traditional mode, periodically execute full optimization
  -20=Highest (Jetsam 0)
  0=Default
  19=Lowest (Jetsam 39)
  Default priority is determined by the launchd process
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
        xmz::log::warn("A1Ctl need set jb env value!");
        xmz::log::info("Use a1ctl status, not cxxa1ctl!");
        return 1;
    }

    a1::config::jb_path g_jb;
    a1::ini::ini_parser pini;

    if (argc < 2) {
        xmz::println(help_text(std::string(argv[0])));
        return 0;
    }

    a1ctl::init_config();

    bool lock_use = pini.get_bool("", "lock_use", true);

    if (lock_use) {
        std::string lock_file = g_jb.a1_dir + "/lock";
        g_lock_mgr.init(lock_file);
        g_lock_mgr.set_enabled(true);
        if (!g_lock_mgr.acquire()) { return 1; }
        signal(SIGINT, signal_handler);
        signal(SIGTERM, signal_handler);
        atexit([]() { g_lock_mgr.release(); });
        //xmz::log::debug("successfully obtained the file lock");
    } /* else {
        //xmz::log::debug("the lock has been disabled. skip this stage");
    } */

    std::string cmd = argv[1];

    if (cmd == "1" || cmd == "start") {
        a1ctl::start_a1();
    } else if (cmd == "0" || cmd == "stop") {
        a1::kill_pid();
        xmz::log::info("A1 has stopped");
    } else if (cmd == "restart") {
        a1::kill_pid();
        sleep(2);
        a1ctl::start_a1();
    } else if (cmd == "status") {
        a1ctl::check_status();
    } else if (cmd == "loop") {
        if (argc < 3) {
            xmz::log::error("usage: loop <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("loop", true);
            a1ctl::update_config("auto_adjust", false);
            a1ctl::update_config("scheduled_guard", false);
            xmz::log::info("loop mode is on (other modes have been turned off automatically)");
        } else if (opt == "off") {
            a1ctl::update_config("loop", false);
            xmz::log::info("loop mode is off");
        } else {
            xmz::log::error("usage: loop <on|off>");
        }
    } else if (cmd == "auto-adjust") {
        if (argc < 3) {
            xmz::log::error("usage: auto-adjust <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("auto_adjust", true);
            a1ctl::update_config("loop", false);
            a1ctl::update_config("scheduled_guard", false);
            xmz::log::info("real-time auto-adjust mode is on (other modes have been turned off automatically)");
        } else if (opt == "off") {
            a1ctl::update_config("auto_adjust", false);
            xmz::log::info("real-time auto-adjust mode is off");
        } else {
            xmz::log::error("usage: auto-adjust <on|off>");
        }
    } else if (cmd == "scheduled-guard" || cmd == "guard") {
        if (argc < 3) {
            xmz::log::error("usage: scheduled-guard <on|off> or guard <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("scheduled_guard", true);
            a1ctl::update_config("loop", false);
            a1ctl::update_config("auto_adjust", false);
            xmz::log::info("scheduled guard mode is on (other modes have been turned off automatically)");
        } else if (opt == "off") {
            a1ctl::update_config("scheduled_guard", false);
            xmz::log::info("scheduled guard mode is off");
        } else {
            xmz::log::error("usage: scheduled-guard <on|off> or guard <on|off>");
        }
    } else if (cmd == "olr") {
        if (argc < 3) {
            xmz::log::error("usage: olr <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("log_reincarnation", true);
            xmz::log::info("log reincarnation is on");
        } else if (opt == "off") {
            a1ctl::update_config("log_reincarnation", false);
            xmz::log::info("log reincarnation is off");
        } else {
            xmz::log::error("usage: olr <on|off>");
        }
    } else if (cmd == "custom") {
        if (argc < 3) {
            xmz::log::error("usage: custom <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("custom_priority_enabled", true);
            xmz::log::info("custom priority is on");
        } else if (opt == "off") {
            a1ctl::update_config("custom_priority_enabled", false);
            xmz::log::info("custom priority is off");
        } else {
            xmz::log::error("usage: custom <on|off>");
        }
    } else if (cmd == "add") {
        if (argc < 4) {
            xmz::log::error("usage: add <high|low> <process> or add <process> <value>");
            return 1;
        }
        std::string type = argv[2];
        std::string process = argv[3];
        int value = -255;
        if (argc >= 5) {
            value = std::atoi(argv[4]);
        }
        a1ctl::add_priority(type, process, value);
    } else if (cmd == "remove") {
        if (argc < 3) {
            xmz::log::error("usage: remove <process>");
            return 1;
        }
        a1ctl::remove_priority("high", argv[2]);
        a1ctl::remove_priority("low", argv[2]);
        a1ctl::remove_priority("custom", argv[2]);
    } else if (cmd == "list") {
        if (argc < 3) {
            xmz::log::error("usage: list <high|low|custom>");
            return 1;
        }
        a1ctl::list_priority(argv[2]);
    } else if (cmd == "clear") {
        if (argc < 3) {
            xmz::log::error("usage: clear <high|low|custom>");
            return 1;
        }
        a1ctl::clear_priority(argv[2]);
    } else if (cmd == "set") {
        if (argc < 4) {
            xmz::log::error("usage: set <high|low|launchd> <value>");
            return 1;
        }
        a1ctl::set_priority_value(argv[2], std::atoi(argv[3]));
    } else if (cmd == "config" || cmd == "show-config") {
        a1ctl::show_config();
    } else if (cmd == "set-interval") {
        if (argc < 3) {
            xmz::log::error("usage: set-interval <seconds>");
            return 1;
        }
        a1ctl::update_config_int("optimize_interval", std::atoi(argv[2]));
    } else if (cmd == "loop-sleep") {
        if (argc < 3) {
            xmz::log::error("usage: loop-sleep <seconds>");
            return 1;
        }
        int val = std::atoi(argv[2]);
        if (val < 1) {
            xmz::log::error("loop sleep time must be a positive integer");
            return 1;
        }
        a1ctl::update_config_int("loop_sleep_interval", val);
    } else if (cmd == "auto-apply") {
        if (argc < 3) {
            xmz::log::error("usage: auto-apply <on|off>");
            return 1;
        }
        bool opt = (std::string(argv[2]) == "on");
        a1ctl::set_auto_apply(&opt);
    } else if (cmd == "restore" || cmd == "restore-config") {
        a1ctl::init_config();
        xmz::log::info("configuration restored from backup");
    } else if (cmd == "compat" || cmd == "compat-mode") {
        if (argc < 3) {
            xmz::log::error("usage: compat <on|off>");
            return 1;
        }
        bool opt = (std::string(argv[2]) == "on");
        a1ctl::compat_mode(&opt);
    } else if (cmd == "help" || cmd == "--help" || cmd == "-h" || cmd == "h" || cmd == "") {
        xmz::println(help_text(std::string(argv[0])));
    } else if (cmd == "version") {
        xmz::println("A1Ctl Version:", a1::_coreapi::a1ctl_version);
    } else if (cmd == "-f") {
        if (argc >= 3 && std::string(argv[2]) == "start") {
            a1ctl::start_a1_foreground();
        } else {
            xmz::log::error("command error: ", (argc >= 3 ? argv[2] : ""));
        }
    } else if (cmd == "lock") {
        if (argc < 3) {
            xmz::log::error("usage: lock <on|off>");
            return 1;
        }
        std::string opt = argv[2];
        if (opt == "on") {
            a1ctl::update_config("lock_use", true);
            xmz::log::info("lock has been turned on");
            xmz::log::info("lock is a mechanism that can ensure that the program is not affected by other processes when running,");
            xmz::log::info("avoid accidents (such as document damage, etc.)");
            xmz::log::info("but it also has its own shortcomings: it can only be executed in a single process and cannot be executed simultaneously.");
        } else if (opt == "off") {
            a1ctl::update_config("lock_use", false);
            xmz::log::info("lock is closed");
            xmz::log::warn("lock has been turned off, and a1 can now perform multi-threaded mode.");
            xmz::log::warn("however, this may cause data such as configuration files to be damaged.");
        } else {
            xmz::log::error("please enter on/off, such as a1ctl lock on");
        }
    } else {
        xmz::log::error("unknown command: ", cmd);
        xmz::log::info("use 'a1ctl help' to view help");
        return 1;
    }
    g_lock_mgr.release();
    return 0;
}
