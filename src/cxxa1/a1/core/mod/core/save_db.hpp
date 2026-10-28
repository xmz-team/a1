// save_db.hpp
#pragma once
#include <string>

#include <libxmz/log.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

#include <a1/core/mod/core/define.hpp>

namespace a1mod {
    // save the database to the file
    inline bool save_db_to_file() {
        a1::config::jb_path g_jb;
        a1::ini::ini_parser parser;
        std::string db_path = g_jb.mod_dir + "/module.db.ini";
        for (const auto& [package_name, entry] : g_module_db.modules) {
            std::string section = package_name;
            parser.set(section, "name", entry.name);
            parser.set(section, "package", entry.package);
            parser.set(section, "version", entry.version);
            parser.set(section, "description", entry.description);
            parser.set(section, "author", entry.author);
            parser.set(section, "maintainer", entry.maintainer);
            parser.set(section, "path", entry.path);
            parser.set(section, "install_base", entry.install_base);
            parser.set(section, "installed_date", entry.installed_date);
            parser.set(section, "last_updated", entry.last_updated);
            if (!entry.depends.empty()) {
                std::string depends_str;
                for (size_t i = 0; i < entry.depends.size(); ++i) {
                    if (i > 0) depends_str += ",";
                    depends_str += entry.depends[i];
                }
                parser.set(section, "depends", depends_str);
            }
            if (!entry.depends_apt.empty()) {
                std::string apt_depends_str;
                for (size_t i = 0; i < entry.depends_apt.size(); ++i) {
                    if (i > 0) apt_depends_str += ",";
                    apt_depends_str += entry.depends_apt[i];
                }
                parser.set(section, "depends_apt", apt_depends_str);
            }
    
            bool is_enabled = g_module_db.is_enabled(entry.package);
            parser.set(section, "status", is_enabled ? "enabled" : "disabled");
        }
        bool result = parser.save_append(db_path);
        if (result) xmz::log::info("Saved database to: " + db_path);
        else        xmz::log::error("Failed to save database to: " + db_path);
        return result;
    }
} /* namespace a1mod */
