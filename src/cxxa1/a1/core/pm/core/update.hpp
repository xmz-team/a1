e/ update.hpp
#pragma once

#include <string>
#include <vector>
#include <set>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/time.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/a1modcore.hpp>
#include <a1/core/pm/a1pm_config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/pm/download.hpp>
#include <a1/core/pm/core/aux.hpp>
#include <a1/core/pm/core/package.hpp>

namespace a1pm {
    inline int update_repo(const std::string& repo_url) {
        a1pm::config cfg;
        if (repo_url.empty()) {
            xmz::log::error("Repository URL cannot be empty");
            return 1;
        }
        std::string repo_name = url_to_repo_name(repo_url);
        std::string cache_dir = cfg.pm_cache;
        std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
        if (!xmz::aux::is_dir(cache_dir)) xmz::fs::mkdir(cache_dir);
        std::string metadata_url = repo_url;
        if (metadata_url.back() != '/') metadata_url += "/";
        metadata_url += "Packages.ini";
        xmz::log::info("Updating repository:", repo_url);
        xmz::println("  URL:", metadata_url);
        std::string error_msg;
        if (!a1pm::curl::download_file(metadata_url, metadata_file, error_msg)) {
            xmz::log::error("Failed to update repository:", error_msg);
            return 1;
        }
        a1::ini::ini_parser parser;
        if (!parser.parse_file(metadata_file)) {
            xmz::log::error("Invalid metadata file:", metadata_file);
            xmz::fs::rmfile(metadata_file);
            return 1;
        }
        a1::ini::ini_parser repo_parser;
        repo_parser.parse_file(cfg.repo_f);
        std::string time = xmz::get_time_str();
        repo_parser.set(repo_url, "last_sync", time);
        repo_parser.save_append(cfg.repo_f);
        auto packages = parser.get_sec();
        xmz::log::info("Repository updated successfully");
        xmz::println("  Packages:", packages.size());
        xmz::println("  Last sync:", time);
        return 0;
    }

    inline int update_all_repos() {
        a1pm::config cfg;
        a1::ini::ini_parser pini;
        if (!pini.parse_file(cfg.repo_f)) {
            xmz::log::error("Failed to parse repo config:", cfg.repo_f);
            return 1;
        }
        auto sections = pini.get_sec();
        if (sections.empty()) {
            xmz::log::error("No repositories configured");
            return 1;
        }
        xmz::log::info("Updating all repositories...");
        xmz::println("Total repositories:", sections.size());
        xmz::println("");
        int success_count = 0;
        int fail_count = 0;
        for (const auto& repo_url : sections) {
            if (update_repo(repo_url) == 0) success_count++;
            else                            fail_count++;
            xmz::println("");
        }
        xmz::log::info("Update completed");
        xmz::println("  Successful:", success_count);
        xmz::println("  Failed:", fail_count);
        return fail_count > 0 ? 1 : 0;
    }

    inline int check_updates() {
        a1pm::config cfg;
        a1::ini::ini_parser pini;
        if (!pini.parse_file(cfg.repo_f)) {
            xmz::log::error("Failed to parse repo config:", cfg.repo_f);
            return 1;
        }
        auto sections = pini.get_sec();
        if (sections.empty()) {
            xmz::log::error("No repositories configured");
            return 1;
        }
        std::string cache_dir = cfg.pm_cache;
        if (!xmz::aux::is_dir(cache_dir)) xmz::fs::mkdir(cache_dir);
        struct update_info {
            std::string package;
            std::string current_version;
            std::string new_version;
            std::string repo;
        };
        std::vector<update_info> updates;
        for (const auto& [pkg_name, entry] : a1mod::g_module_db.modules) {
            std::string current_version = entry.version;
            std::string found_new_version;
            std::string found_repo;
            for (const auto& repo_url : sections) {
                std::string repo_name = url_to_repo_name(repo_url);
                std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
                if (!xmz::aux::is_file(metadata_file)) continue;
                a1::ini::ini_parser pkg_parser;
                if (!pkg_parser.parse_file(metadata_file)) continue;
                std::string version = pkg_parser.get(pkg_name, "version", "");
                if (!version.empty()) {
                    if (a1mod::version::compare(version, current_version) > 0) {
                        found_new_version = version;
                        found_repo = repo_url;
                        break;
                    }
                }
            }

            if (!found_new_version.empty()) {
                update_info info;
                info.package = pkg_name;
                info.current_version = current_version;
                info.new_version = found_new_version;
                info.repo = found_repo;
                updates.push_back(info);
            }
        }

        if (updates.empty()) {
            xmz::println("All packages are up to date!");
            return 0;
        }

        xmz::println("Available Updates");
        xmz::println("Found", updates.size(), "package(s) with updates:");
        xmz::println("");
        for (const auto& update : updates) {
            xmz::println("  ", update.package);
            xmz::println("    Current version:", update.current_version);
            xmz::println("    New version:    ", update.new_version);
            xmz::println("    Repository:     ", update.repo);
            xmz::println("");
        }

        xmz::println("To update all packages, run: update");
        xmz::println("To update specific package: update <package>");
        return 0;
    }

    inline int update_package(const std::string& package) {
        auto it = a1mod::g_module_db.modules.find(package);
        if (it == a1mod::g_module_db.modules.end()) {
            xmz::log::error("Package not installed:", package);
            xmz::log::info("Use 'install' to install it first");
            return 1;
        }

        xmz::log::info("Updating package:", package);
        xmz::println("  Current version:", it->second.version);
        xmz::log::info("Removing old version...");
        if (a1mod::remove(package) != 0) {
            xmz::log::error("Failed to remove old version");
            return 1;
        }

        xmz::log::info("Installing new version...");
        return install_package(package);
    }

    inline int update_all_packages() {
        a1pm::config cfg;
        a1::ini::ini_parser pini;
        xmz::log::info("Updating repository metadata first...");
        if (update_all_repos() != 0) xmz::log::warn("Some repositories failed to update, continuing...");
        xmz::log::info("Checking for package updates...");
        if (!pini.parse_file(cfg.repo_f)) { xmz::log::error("Failed to parse repo config:", cfg.repo_f); return 1; }
        auto sections = pini.get_sec();
        if (sections.empty()) { xmz::log::error("No repositories configured"); return 1; }
        std::string cache_dir = cfg.pm_cache;
        std::vector<std::string> packages_to_update;
        for (const auto& [pkg_name, entry] : a1mod::g_module_db.modules) {
            std::string current_version = entry.version;
            bool has_update = false;
            for (const auto& repo_url : sections) {
                std::string repo_name = url_to_repo_name(repo_url);
                std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
                if (!xmz::aux::is_file(metadata_file)) continue;
                a1::ini::ini_parser pkg_parser;
                if (!pkg_parser.parse_file(metadata_file)) continue;
                std::string version = pkg_parser.get(pkg_name, "version", "");
                if (!version.empty() && a1mod::version::compare(version, current_version) > 0) {
                    has_update = true;
                    break;
                }
            }

            if (has_update) packages_to_update.push_back(pkg_name);
        }

        if (packages_to_update.empty()) {
            xmz::println("All packages are up to date!");
            return 0;
        }

        xmz::println("Found", packages_to_update.size(), "package(s) to update:");
        for (const auto& pkg : packages_to_update) xmz::println("   -", pkg);
        xmz::println("");
        int success_count = 0;
        int fail_count = 0;
        for (const auto& pkg : packages_to_update) {
            if (update_package(pkg) == 0) success_count++;
            else                          fail_count++;
            xmz::println("");
        }
        xmz::log::info("Update completed");
        xmz::println("  Successful:", success_count);
        xmz::println("  Failed:", fail_count);
        return fail_count > 0 ? 1 : 0;
    }

    inline int update(const std::string& target = "") {
        if (target.empty()) return update_all_packages();
        else if (target.find("http://") == 0 || target.find("https://") == 0) return update_repo(target);
        else return update_package(target);
    }
} /* namespace a1pm */

