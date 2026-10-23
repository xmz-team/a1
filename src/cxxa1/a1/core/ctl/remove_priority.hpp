// remove_priority.hpp
#pragma once
#include <string>

#include <a1/core/ctl/aux.hpp>
#include <a1/core/config.hpp>
#include <a1/core/myini.hop>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
    inline void remove_priority(const std::string& priority_opt, const std::string& process_name) {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser pini;
        if (priority_opt == "high" || priority_opt == "h") {
            if (xmz::aux::is_file(g_jb.high_f)) {
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
            if (xmz::aux::is_file(g_jb.low_f)) {
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
            if (xmz::aux::is_file(g_jb.custom_f)) {
                if (xmz::fs::fmfindstr(g_jb.custom_f, process_name) == true) {
                    pini.parse_file(g_jb.custom_f);
                    pini.rmkey("", process_name);
                    pini.save_cover(g_jb.custom_f);
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
} /* namespace a1ctl */
