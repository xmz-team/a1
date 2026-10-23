// cmd.hpp
#pragma once
#include <string>
#include <cstdlib>

#include <a1/core/ctl/aux.hpp>
#include <a1/core/ctl/update_config.hpp>
#include <a1/core/config.hpp>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
    inline void set_auto_apply(const bool opt) {
        if (opt == true) {
            update_config("auto_apply", true);
            xmz::log::info("automatic effect has been turned on.");
            auto_apply_check();
        } else {
            update_config("auto_apply", false);
            xmz::log::info("automatic effect has been turned off.");
        }
    }

    inline void compat_mode(const bool opt) {
        using xmz::aux::parselink;
        a1::config::jb_path g_jb;
        if (opt == true) {
            update_config("compat_mode", true);
            const char* jbenv_cstr = std::getenv("jbenv");
            std::string jbenv = jbenv_cstr ? jbenv_cstr : "";
            if (jbenv == "iphoneos-arm64e") {
                if (xmz::aux::path_exist(parselink(g_jb.jb)) == 1) return;
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/var/jb")) == 1) xmz::fs::mklndir(g_jb.jb, g_jb.jb + "/var/jb");
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/var/a1")) == 1) xmz::fs::mklndir(g_jb.a1_dir, g_jb.jb + "/var/");
                if (xmz::aux::path_exist(parselink(g_jb.jb + "/rootfs")) == 0) if (xmz::aux::path_exist(parselink(g_jb.jb + "/rootfs/var/a1")) == 1) xmz::fs::mklndir(g_jb.a1_dir, g_jb.jb + "/rootfs/var/a1");
                xmz::log::info("the operation is successful, and the compatibility mode has been turned on.");
            } else {
                if (jbenv == "iphoneos-arm64" || jbenv == "iphoneos-arm") xmz::log::info("rootless does not need compatibility mode, and this operation will not be executed.");
                else xmz::log::warn("incompatible jailbreak:", jbenv);
            }
        } else if (opt == false) {
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
            if (priority_type == "high" || priority_type == "h") { update_config_int("high_priority", value);
            } else if (priority_type == "low" || priority_type == "l") { update_config_int("low_priority", value);
            } else if (priority_type == "launchd" || priority_type == "lchd") { update_config_int("launchd_priority", value);
            } else {
                xmz::log::error("undefined options:", priority_type)
                xmz::log::error("priority_type cannot be empty, priority_type need high|low|launchd");
                return 1;
            }
        } else { xmz::log::error("value must be between 0 and 39"); return 1; }
        return 0;
    }

    inline void mod_switch_mode(const bool opt) {
        if (opt) {
            update_config("module_switch", true);
            xmz::log::info("the module system has been turned on");
        } else {
            update_config("module_switch", false);
            xmz::log::info("the module system has been shut down");
        }
    }
} /* namespace a1ctl */
