// a1mod.hpp
#pragma once
#include <string>
#include <vector>
#include <map>
#include <filesystem>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/str.hpp>
#include <libxmz/runsh.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

#include <a1/core/mod/a1mod_config.hpp>
#include <a1/core/mod/a1mod_version.hpp>
#include <a1/core/mod/a1mod_depends.hpp>

namespace a1mod {
    // module database
    struct module_db {
        std::map<std::string, module_entry> modules;
        std::vector<std::string> enabled_modules;
        std::vector<std::string> disabled_modules;
        std::string last_updated;
        bool is_enabled(const std::string& name) const { return std::find(enabled_modules.begin(), enabled_modules.end(), name) != enabled_modules.end(); }
        bool is_disabled(const std::string& name) const { return std::find(disabled_modules.begin(), disabled_modules.end(), name) != disabled_modules.end(); }
    };
    // global module database instance
    inline module_db g_module_db;

    namespace cmd {
        inline int unzip(const std::string& filename, const std::string& dest) { return xmz::cmd::run_shell("unzip -q " + filename + " -d " + dest); }
    }
    // parse authors from authers.ini
    inline std::vector<std::string> parse_authors(const std::string& filepath) {
        std::vector<std::string> authors;
        a1::ini::ini_parser parser;
        if (!parser.parse_file(filepath)) return authors;
        std::string authors_str = parser.get("", "authers", "");
        if (!authors_str.empty()) {
            auto parts = xmz::str::split(authors_str, ",");
            for (auto& p : parts) {
                p = xmz::str::trim(p);
                if (!p.empty()) authors.push_back(p);
            }
        }
        return authors;
    }
    // check if author is official
    inline bool is_official_author(const std::string& author, const config& cfg) {
        auto authors = parse_authors(cfg.authers);
        return std::find(authors.begin(), authors.end(), author) != authors.end();
    }
    // Initialize module system
    inline void init_system(const a1mod::config& cfg, const a1::config::jb_path& g_jb) {
        xmz::log::info("Initializing module system...");
        // create directory structure
        if (xmz::aux::is_dir(g_jb.mod_dir) == 1) {
            xmz::fs::mkdir(g_jb.mod_dir);
            xmz::fs::mkdir(g_jb.mod_dir + "/downloadas");
            xmz::fs::mkdir(g_jb.mod_dir + "/install");
            xmz::fs::mkdir(cfg.mod_install_tmp);
        }
        if (xmz::aux::is_dir(cfg.users) == 1) { xmz::fs::mkdir(cfg.users); }
        if (xmz::aux::is_dir(cfg.authers) == 1) { xmz::fs::mkdir(cfg.authers); }
        if (xmz::aux::exist(cfg.authers + "/authers.ini") == 1) { xmz::fs::writefile("authers: XMZ, LF, AD-iOS", cfg.authers + "/authers.ini"); }
        if (xmz::aux::is_dir(g_jb.mod_dir + "/store") == 1) {
            xmz::fs::mkdir(g_jb.mod_dir + "/store");
            xmz::fs::mkdir(g_jb.mod_dir + "/store/users");
            xmz::fs::mkdir(g_jb.mod_dir + "/store/official");
        }
        g_module_db.last_updated = xmz::get_time_str();
    }
    // check if required fields are present
    inline bool check_required(const packinfo& info) {
        auto missing = info.get_miss_fields();
        if (!missing.empty()) {
            xmz::log::error("Missing required fields:");
            for (const auto& field : missing) { xmz::log::error("  - " + field); }
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
            auto result = xmz::cmd::run_shell_capture(
                "dpkg -l " + pkg_trimmed + " 2>/dev/null | grep '^ii'"
            );
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
        if (it == g_module_db.modules.end()) {
            return {false, conflict_result::none};
        }
        if (it->second.author == author) { return {true, conflict_result::same_author}; }
        return {true, conflict_result::different_author};
    }
    // add module to database
    inline void add_to_db(const module_entry& entry, bool is_official) {
        g_module_db.modules[entry.name] = entry;
        g_module_db.last_updated = xmz::get_time_str();
        g_module_db.enabled_modules.push_back(entry.name);
        xmz::log::info("Added to database:" + entry.name + "(" + (is_official ? "official" : "user") + ")");
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
        enabled.erase(std::remove(enabled.begin(), enabled.end(), package), 
                     enabled.end());
        auto& disabled = g_module_db.disabled_modules;
        disabled.erase(std::remove(disabled.begin(), disabled.end(), package), 
                      disabled.end());
        g_module_db.last_updated = xmz::get_time_str();
        return true;
    }
    // list all modules
    inline void list_modules() {
        xmz::println("=== Installed Modules ===");
        if (g_module_db.modules.empty()) {
            xmz::println("  No modules installed");
            return;
        }
        for (const auto& [name, entry] : g_module_db.modules) {
            xmz::println("");
            xmz::println("  " + name + ":" + entry.name + " (v" + entry.version + ")");
            xmz::println("    Author:" + entry.author + ", Maintainer:" + entry.maintainer);
            xmz::println("    Description:" + entry.description);
            xmz::println("    Installed:" + entry.installed_date);
            if (!entry.depends.empty()) {
                xmz::println("    Dependencies:");
                for (const auto& dep : entry.depends) { xmz::println("      - " + dep); }
            }
            if (!entry.depends_apt.empty()) {
                xmz::println("    System Dependencies:");
                for (const auto& dep : entry.depends_apt) {xmz::println("      - " + dep); }
            }
            bool enabled = g_module_db.is_enabled(name);
            xmz::println("    Status:" + std::string(enabled ? "Enabled" : "Disabled"));
        }
    }
    // enable module
    inline void enable_module(const std::string& package) {
        auto& disabled = g_module_db.disabled_modules;
        auto it = std::find(disabled.begin(), disabled.end(), package);
        if (it != disabled.end()) { disabled.erase(it); }
        if (!g_module_db.is_enabled(package)) { g_module_db.enabled_modules.push_back(package); }
        xmz::log::info("Module enabled:" + package);
    }
    // disable module
    inline void disable_module(const std::string& package) {
        auto& enabled = g_module_db.enabled_modules;
        auto it = std::find(enabled.begin(), enabled.end(), package);
        if (it != enabled.end()) { enabled.erase(it); }
        if (!g_module_db.is_disabled(package)) {
            g_module_db.disabled_modules.push_back(package);
        }
        xmz::log::info("Module disabled:" + package);
    }

    inline int install(const std::string& filepath) {
        std::filesystem::path p(filepath);
        std::string modname = p.filename();
        config cfg;
        if (xmz::aux::is_file(filepath) != 0) {
            xmz::log::error("File not found:" + filepath);
            return 1;
        }
        // check file extension
        if (filepath.find(".a1mod") == std::string::npos && 
            filepath.find(".a1module.zip") == std::string::npos) {
            xmz::log::error("Must be .a1module.zip or .a1mod file");
            return 1;
        }
        xmz::log::info("Installing module:" + filepath);
        // create temp directory
        std::string temp_dir = cfg.mod_install_tmp + "/install_" + modname;
        xmz::fs::mkdir(temp_dir);
        // unzip module
        xmz::log::info("Extracting module...");
        if (cmd::unzip(filepath, temp_dir) != 0) {
            xmz::log::error("Failed to extract module");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // find control.ini
        std::string control_file;
        if (xmz::aux::is_file(temp_dir + "/control.ini") == 0) {
            control_file = temp_dir + "/control.ini";
        } else {
            // search for control.ini in subdirectories
            for (const auto& entry : std::filesystem::directory_iterator(temp_dir)) {
                if (entry.is_directory()) {
                    std::string sub_control = entry.path().string() + "/control.ini";
                    if (xmz::aux::is_file(sub_control) == 0) {
                        control_file = sub_control;
                        break;
                    }
                }
            }
        }
        if (control_file.empty()) {
            xmz::log::error("control.ini not found in module");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // parse module info
        xmz::log::info("Parsing module metadata...");
        auto info = parse_packfile(control_file);
        // validate required fields
        if (!check_required(info)) {
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // display module info
        xmz::println("Module information:");
        xmz::println("  Package:" + info.package);
        xmz::println("  Name:" + info.name);
        xmz::println("  Version:" + info.version);
        xmz::println("  Description:" + info.descr);
        // check dependencies
        xmz::log::info("Checking dependencies...");
        if (!check_depends(info)) {
            xmz::log::error("Module dependencies not satisfied");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // check APT dependencies
        if (!check_apt_depends(info)) {
            xmz::log::error("System dependencies not satisfied");
            xmz::fs::recrmdir(temp_dir);
            return 1;
        }
        // check conflicts
        auto [has_conflict, conflict] = check_conflict(info.package, 
                                                        info.maintainer.empty() ? 
                                                        "unknown" : info.maintainer[0], 
                                                        cfg);
        if (has_conflict) {
            if (conflict == conflict_result::different_author) {
                xmz::log::error("Module" + info.package + "already exists with different author");
                xmz::fs::recrmdir(temp_dir);
                return 1;
            } else {
                xmz::log::warn("Module already exists, updating...");
                remove_from_db(info.package);
            }
        }
        // determine if official
        bool is_official = false;
        std::string author = info.maintainer.empty() ? "unknown" : info.maintainer[0];
        if (!info.auther.empty()) { author = info.auther[0]; }
        is_official = is_official_author(author, cfg);
        // set install path
        std::string install_base;
        if (is_official) { install_base = cfg.authers + "/" + author + "/" + info.package; } else { install_base = cfg.users + "/" + author + "/" + info.package; }
        // clean and create install directory
        xmz::fs::recrmdir(install_base);
        xmz::fs::mkdir(install_base);
        xmz::log::info("Installing to:" + install_base);
        std::string source_dir = std::filesystem::path(control_file).parent_path().string();
        for (const auto& entry : std::filesystem::directory_iterator(source_dir)) {
            std::string dest = install_base + "/" + entry.path().filename().string();
            if (entry.is_directory()) { xmz::fs::cp(xmz::fs::cptype::recdir, entry.path().string(), dest); } else { xmz::fs::cp(xmz::fs::cptype::file, entry.path().string(), dest); }
        }
        for (const auto& entry : std::filesystem::directory_iterator(install_base)) { if (entry.path().extension() == ".lua") { chmod(entry.path().c_str(), 0755); } }
        // create module entry
        module_entry entry;
        entry.name = info.name;
        entry.package = info.package;
        entry.version = info.version;
        entry.description = info.descr;
        entry.author = author;
        entry.maintainer = info.maintainer.empty() ? author : info.maintainer[0];
        entry.path = install_base;
        entry.install_base = install_base;
        entry.installed_date = xmz::get_time_str();
        entry.last_updated = xmz::get_time_str();
        entry.depends = info.depends;
        entry.depends_apt = info.depends_apt;
        add_to_db(entry, is_official);
        xmz::fs::recrmdir(temp_dir);
        xmz::log::info("Module installed successfully!");
        xmz::println("  Name:" + info.name);
        xmz::println("  Package:" + info.package);
        xmz::println("  Version:" + info.version);
        xmz::println("  Author:" + author);
        xmz::println("  Type:" + std::string(is_official ? "Official" : "User"));
        xmz::println("  Location:" + install_base);
        return 0;
    }
    // remove module
    inline int remove(const std::string& package) {
        auto it = g_module_db.modules.find(package);
        if (it == g_module_db.modules.end()) {
            xmz::log::error("Module not found:" + package);
            return 1;
        }
        xmz::log::info("Removing module:" + package);
        xmz::println("  Name:" + it->second.name);
        xmz::println("  Version:" + it->second.version);
        xmz::println("  Author:" + it->second.author);
        // remove files
        if (xmz::aux::is_dir(it->second.install_base) == 0) { xmz::fs::recrmdir(it->second.install_base); }
        // remove from database
        remove_from_db(package);
        xmz::log::info("Module removed:" + package);
        return 0;
    }
    inline int package_module(const std::string& path, const std::string& name) {
        if (path == "") {
            xmz::log::error("the path can’t be empty!");
            return 1;
        }
        if (name == "") {
            xmz::log::error("the name can’t be empty!");
            return 1;
        }
        if (xmz::aux::is_dir(path) == 1) {
            xmz::log::error("path:", path, "not exist");
        }
        std::string cmd = std::string("zip -r -9") + " " + name + ".a1mod" + " " + path;
        return xmz::cmd::runsh(cmd);
    }
} // namespace a1mod
