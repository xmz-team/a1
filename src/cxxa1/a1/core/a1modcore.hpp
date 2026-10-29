// a1modcore.hpp
#pragma once
#include <string>
#include <filesystem>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/runsh.hpp>
#include <libxmz/str.hpp>
#include <libxmz/time.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

#include <a1/core/mod/core/define.hpp>
#include <a1/core/mod/all.hpp>
#include <a1/core/mod/a1mod_config.hpp>
#include <a1/core/mod/zip.hpp>

namespace a1mod {
    inline int install(const std::string& filepath) {
        std::filesystem::path p(filepath);
        std::string modname = p.filename();
        config cfg;
        if (!xmz::aux::is_file(filepath)) {
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
        if (xmz::aux::is_file(temp_dir + "/control.ini")) {
            control_file = temp_dir + "/control.ini";
        } else {
            // search for control.ini in subdirectories
            for (const auto& entry : std::filesystem::directory_iterator(temp_dir)) {
                if (entry.is_directory()) {
                    std::string sub_control = entry.path().string() + "/control.ini";
                    if (xmz::aux::is_file(sub_control)) {
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
        xmz::println("  Description:" + info.description);
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
        auto [has_conflict, conflict] = check_conflict(info.package, info.maintainer.empty() ? "unknown" : info.maintainer[0], cfg);
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
        std::string author = info.maintainer.empty() ? "unknown" : info.maintainer[0];
        if (!info.author.empty()) { author = info.author[0]; }
        // set install path
        std::string install_base;
        install_base = cfg.users + "/" + author + "/" + info.package;
        // clean and create install directory
        xmz::fs::recrmdir(install_base);
        xmz::fs::mkdir(install_base);
        xmz::log::info("Installing to:" + install_base);
        std::string source_dir = std::filesystem::path(control_file).parent_path().string();
        for (const auto& entry : std::filesystem::directory_iterator(source_dir)) {
            std::string dest = install_base + "/" + entry.path().filename().string();
            if (entry.is_directory()) xmz::fs::cp(xmz::fs::cptype::recdir, entry.path().string(), dest);
            else                      xmz::fs::cp(xmz::fs::cptype::file, entry.path().string(), dest);
        }
        for (const auto& entry : std::filesystem::directory_iterator(install_base)) if (entry.path().extension() == ".lua") chmod(entry.path().c_str(), 0755);
        // create module entry
        module_entry entry;
        entry.name             = info.name;
        entry.package          = info.package;
        entry.version          = info.version;
        entry.description      = info.description;
        entry.author           = author;
        entry.maintainer       = info.maintainer.empty() ? author : info.maintainer[0];
        entry.path             = install_base;
        entry.install_base     = install_base;
        entry.installed_date   = xmz::get_time_str();
        entry.last_updated     = xmz::get_time_str();
        entry.depends          = info.depends;
        entry.depends_apt      = info.depends_apt;
        add_to_db(entry);
        xmz::fs::recrmdir(temp_dir);
        xmz::log::info("Module installed successfully!");
        xmz::println("  Name:" + info.name);
        xmz::println("  Package:" + info.package);
        xmz::println("  Version:" + info.version);
        xmz::println("  Author:" + author);
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
        if (xmz::aux::is_dir(it->second.install_base)) xmz::fs::recrmdir(it->second.install_base);
        // remove from database
        remove_from_db(package);
        xmz::log::info("Module removed:" + package);
        return 0;
    }

    inline int package_module(const std::string& path, const std::string& name) {
        if (path.empty()) {
            xmz::log::error("the path can’t be empty!");
            return 1;
        }
        if (name.empty()) {
            xmz::log::error("the name can’t be empty!");
            return 1;
        }
        if (!xmz::aux::is_dir(path)) xmz::log::error("path:", path, "not exist");
        return cmd::zip(name, path);
    }
} // namespace a1mod
