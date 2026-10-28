// curd.hpp
#pragma once
#include <string>
#include <algorithm>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/str.hpp>
#include <libxmz/time.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/mod/core/define.hpp>
#include <a1/core/mod/core/save_db.hpp>

namespace a1mod {
    // add module to database
    inline void add_to_db(const module_entry& entry) {
        g_module_db.modules[entry.package] = entry;
        g_module_db.last_updated           = xmz::get_time_str();
        g_module_db.enabled_modules.push_back(entry.package);
        xmz::log::info("Added to database:" + entry.package);
        save_db_to_file();
    }
    // remove module from database
    inline bool remove_from_db(const std::string& package) {
        auto it = g_module_db.modules.find(package);
        if (it == g_module_db.modules.end()) {
            xmz::log::error("Module not found:" + package);
            return false;
        }
        g_module_db.modules.erase(it);
        // remove from enabled/disabled lists
        auto& enabled = g_module_db.enabled_modules;
        enabled.erase(std::remove(enabled.begin(), enabled.end(), package), enabled.end());
        auto& disabled = g_module_db.disabled_modules;
        disabled.erase(std::remove(disabled.begin(), disabled.end(), package), disabled.end());
        g_module_db.last_updated = xmz::get_time_str();
        save_db_to_file();
        return true;
    }
    // list modules
    inline void list_modules() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser parser;
        std::string db_path = g_jb.mod_dir + "/module.db.ini";
        if (!parser.parse_file(db_path)) {
            xmz::println("Failed to parse module database");
            return;
        }
        auto sections = parser.get_sec();
        if (sections.empty()) {
            xmz::println("  No modules installed");
            return;
        }
        xmz::println("Installed Modules");
        for (const auto& section : sections) {
            if (section.empty()) continue;
            std::string name = parser.get(section, "name", "");
            std::string version = parser.get(section, "version", "");
            std::string author = parser.get(section, "author", "");
            std::string maintainer = parser.get(section, "maintainer", "");
            std::string description = parser.get(section, "description", "");
            std::string depends_str = parser.get(section, "depends", "");
            std::string depends_apt_str = parser.get(section, "depends_apt", "");
            std::string enabled_str = parser.get(section, "enabled", "true");
            xmz::println("");
            xmz::println("  " + section + ":" + name + " (v" + version + ")");
            xmz::println("    Author:" + author + ", Maintainer:" + maintainer);
            xmz::println("    Description:" + description);
            if (!depends_str.empty()) {
                xmz::println("    Dependencies:");
                auto deps = xmz::str::split(depends_str, ",");
                for (const auto& dep : deps) {
                    std::string trimmed = xmz::str::trim(dep);
                    if (!trimmed.empty()) xmz::println("      - " + trimmed);
                }
            }
            if (!depends_apt_str.empty()) {
                xmz::println("    System Dependencies:");
                auto deps_apt = xmz::str::split(depends_apt_str, ",");
                for (const auto& dep : deps_apt) {
                    std::string trimmed = xmz::str::trim(dep);
                    if (!trimmed.empty()) xmz::println("      - " + trimmed);
                }
            }
            bool enabled = (enabled_str == "true" || enabled_str == "1" || enabled_str == "yes");
            xmz::println("    Status:" + std::string(enabled ? "Enabled" : "Disabled"));
        }
    }
    // enable module
    inline void enable_module(const std::string& package) {
        auto& disabled = g_module_db.disabled_modules;
        auto it = std::find(disabled.begin(), disabled.end(), package);
        if (it != disabled.end()) disabled.erase(it);
        if (!g_module_db.is_enabled(package)) g_module_db.enabled_modules.push_back(package);
        xmz::log::info("Module enabled:" + package);
    }
    // disable module
    inline void disable_module(const std::string& package) {
        auto& enabled = g_module_db.enabled_modules;
        auto it = std::find(enabled.begin(), enabled.end(), package);
        if (it != enabled.end()) enabled.erase(it);
        if (!g_module_db.is_disabled(package)) g_module_db.disabled_modules.push_back(package);
        xmz::log::info("Module disabled:" + package);
    }
} /* namespace a1mod */
