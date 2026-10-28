// load_db.hpp
#pragma once
#include <string>

#include <libxmz/log.hpp>
#include <libxmz/str.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

#include <a1/core/mod/core/define.hpp>

namespace a1mod {
    // load the database from the file system
    inline bool load_db_from_file() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser parser;
        std::string db_path = g_jb.mod_dir + "/module.db.ini";
        if (!parser.parse_file(db_path)) {
            xmz::log::warn("no existing module database found, creating new one");
            return false;
        }
        g_module_db.modules.clear();
        g_module_db.enabled_modules.clear();
        g_module_db.disabled_modules.clear();
        auto sections = parser.get_sec();
        for (const auto& section : sections) {
            module_entry entry;
            entry.name = parser.get(section, "name", "");
            entry.package = parser.get(section, "package", "");
            entry.version = parser.get(section, "version", "");
            entry.description = parser.get(section, "description", "");
            entry.author = parser.get(section, "author", "");
            entry.maintainer = parser.get(section, "maintainer", "");
            entry.path = parser.get(section, "path", "");
            entry.install_base = parser.get(section, "install_base", "");
            entry.installed_date = parser.get(section, "installed_date", "");
            entry.last_updated = parser.get(section, "last_updated", "");
            std::string depends_str = parser.get(section, "depends", "");
            if (!depends_str.empty()) {
                auto parts = xmz::str::split(depends_str, ",");
                for (auto& p : parts) {
                    p = xmz::str::trim(p);
                    if (!p.empty()) entry.depends.push_back(p);
                }
            }
            std::string apt_depends_str = parser.get(section, "depends_apt", "");
            if (!apt_depends_str.empty()) {
                auto parts = xmz::str::split(apt_depends_str, ",");
                for (auto& p : parts) {
                    p = xmz::str::trim(p);
                    if (!p.empty()) entry.depends_apt.push_back(p);
                }
            }
            std::string status = parser.get(section, "status", "enabled");
            if (status == "enabled") g_module_db.enabled_modules.push_back(entry.package);
            else g_module_db.disabled_modules.push_back(entry.package);
            g_module_db.modules[entry.package] = entry;
        }
        xmz::log::info("Loaded " + std::to_string(g_module_db.modules.size()) + " modules from database");
        return true;
    }
} /* namespace a1mod */
