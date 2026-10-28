// aux.hpp
#pragma once
#include <string>
#include <vector>
#include <map>
#include <utility>

#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/runsh.hpp>
#include <libxmz/str.hpp>
#include <libxmz/time.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/mod/a1mod_config.hpp>
#include <a1/core/mod/core/define.hpp>
#include <a1/core/mod/a1mod_depends.hpp>
#include <a1/core/mod/a1mod_version.hpp>
#include <a1/core/mod/core/load_db.hpp>
#include <a1/core/mod/core/save_db.hpp>

namespace a1mod {
    // Initialize module system
    inline void init_system(const a1mod::config& cfg, const a1::config::jb_path& g_jb) {
        xmz::log::info("Initializing module system...");
        if (!xmz::aux::is_dir(g_jb.mod_dir)) {
            xmz::fs::mkdir(g_jb.mod_dir);
            xmz::fs::mkdir(g_jb.mod_dir + "/downloads");
            xmz::fs::mkdir(g_jb.mod_dir + "/install");
            xmz::fs::mkdir(cfg.mod_install_tmp);
        }
        if (!xmz::aux::is_dir(cfg.users)) xmz::fs::mkdir(cfg.users);
        if (!xmz::aux::is_dir(cfg.authors)) xmz::fs::mkdir(cfg.authors);
        if (!xmz::aux::is_dir(g_jb.mod_dir + "/store")) {
            xmz::fs::mkdir(g_jb.mod_dir + "/store");
            xmz::fs::mkdir(g_jb.mod_dir + "/store/users");
        }
        load_db_from_file();
        g_module_db.last_updated = xmz::get_time_str();
        save_db_to_file();
    }
    // parse authors from author.ini
    inline std::vector<std::string> parse_authors(const std::string& filepath) {
        std::vector<std::string> authors;
        a1::ini::ini_parser parser;
        if (!parser.parse_file(filepath)) return authors;
        std::string authors_str = parser.get("", "author", "");
        if (!authors_str.empty()) {
            auto parts = xmz::str::split(authors_str, ",");
            for (auto& p : parts) {
                p = xmz::str::trim(p);
                if (!p.empty()) authors.push_back(p);
            }
        }
        return authors;
    }
    // check if required fields are present
    inline bool check_required(const packinfo& info) {
        auto missing = info.get_miss_fields();
        if (!missing.empty()) {
            xmz::log::error("Missing required fields:");
            for (const auto& field : missing) xmz::log::error("  - " + field);
            return false;
        }
        return true;
    }
    // check module dependencies
    inline bool check_depends(const packinfo& info) {
        if (info.depends.empty()) return true;
        for (const auto& dep_str : info.depends) {
            auto deps = depends::parse_depends(dep_str);
            for (const auto& dep : deps) {
                auto it = g_module_db.modules.find(dep.name);
                if (it == g_module_db.modules.end()) {
                    if (dep.optional) continue;
                    xmz::log::error("Missing dependency:" + dep.name);
                    return false;
                }
                if (!dep.version_constraint.empty()) {
                    if (!version::satisfies(it->second.version, 
                                            dep.version_constraint)) {
                        xmz::log::error("Version mismatch for" + dep.name + 
                                        ": required" + dep.version_constraint + 
                                        ", found" + it->second.version);
                        return false;
                    }
                }
            }
        }
        return true;
    }
    // check APT dependencies
    inline bool check_apt_depends(const packinfo& info) {
        if (info.depends_apt.empty()) return true;
        for (const auto& pkg : info.depends_apt) {
            std::string pkg_trimmed = xmz::str::trim(pkg);
            if (pkg_trimmed.empty()) continue;
            // check if package is installed via dpkg
            auto result = xmz::cmd::run_shell_capture("dpkg -l " + pkg_trimmed + " 2>/dev/null | grep '^ii'");
            if (result.exit_code != 0) {
                xmz::log::error("Missing system package:" + pkg_trimmed);
                xmz::log::info("Install with: apt install" + pkg_trimmed);
                return false;
            }
        }
        return true;
    }
    // check for module conflicts
    enum class conflict_result {
        none,
        same_author,
        different_author
    };
    inline std::pair<bool, conflict_result> check_conflict(
        const std::string& package, 
        const std::string& author,
        const config& cfg) {
        auto it = g_module_db.modules.find(package);
        if (it == g_module_db.modules.end()) return {false, conflict_result::none};
        if (it->second.author == author)     return {true, conflict_result::same_author};
        return {true, conflict_result::different_author};
    }
} /* namespace a1mod */
