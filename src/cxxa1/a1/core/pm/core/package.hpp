// package.hpp
#pragma once

#include <string>
#include <vector>
#include <set>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/a1modcore.hpp>
#include <a1/core/pm/a1pm_config.hpp>
#include <a1/core/myini.hpp>

namespace a1pm {
    inline int install_package(const std::string& package) {
        std::set<std::string> installed;
        std::set<std::string> visiting;
        for (const auto& [name, entry] : a1mod::g_module_db.modules) installed.insert(name);
        return aux::install_package_with_deps(package, installed, visiting);
    }

    inline int remove_package(const std::string& package) { return a1mod::remove(package); }

    inline int search_package(const std::string& query) {
        a1pm::config cfg;
        a1::ini::ini_parser pini;
        if (query.empty()) {
            xmz::log::error("Search query cannot be empty");
            return 1;
        }

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

        struct search_result {
            std::string package;
            std::string version;
            std::string name;
            std::string description;
            std::string repo;
            bool is_installed;
        };
        std::vector<search_result> results;
        std::string query_lower = query;
        std::transform(query_lower.begin(), query_lower.end(), query_lower.begin(), ::tolower);
        for (const auto& repo_url : sections) {
            std::string repo_name = url_to_repo_name(repo_url);
            std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
            if (!xmz::aux::is_file(metadata_file)) {
                xmz::log::warn("Repository metadata not found:", repo_url);
                xmz::log::info("Please sync repository first");
                continue;
            }

            a1::ini::ini_parser pkg_parser;
            if (!pkg_parser.parse_file(metadata_file)) {
                xmz::log::warn("Failed to parse metadata for:", repo_url);
                continue;
            }

            auto pkg_sections = pkg_parser.get_sec();
            for (const auto& pkg_name : pkg_sections) {
                std::string version = pkg_parser.get(pkg_name, "version", "");
                std::string name = pkg_parser.get(pkg_name, "name", pkg_name);
                std::string description = pkg_parser.get(pkg_name, "description", "");
                std::string pkg_lower = pkg_name;
                std::string name_lower = name;
                std::string desc_lower = description;
                std::transform(pkg_lower.begin(), pkg_lower.end(), pkg_lower.begin(), ::tolower);
                std::transform(name_lower.begin(), name_lower.end(), name_lower.begin(), ::tolower);
                std::transform(desc_lower.begin(), desc_lower.end(), desc_lower.begin(), ::tolower);
                bool match = false;
                if (pkg_lower.find(query_lower) != std::string::npos ||
                    name_lower.find(query_lower) != std::string::npos ||
                    desc_lower.find(query_lower) != std::string::npos) {
                    match = true;
                }

                if (match) {
                    search_result result;
                    result.package = pkg_name;
                    result.version = version;
                    result.name = name.empty() ? pkg_name : name;
                    result.description = description;
                    result.repo = repo_url;
                    result.is_installed = a1mod::g_module_db.modules.find(pkg_name) != a1mod::g_module_db.modules.end();
                    results.push_back(result);
                }
            }
        }

        if (results.empty()) {
            xmz::println("No packages found matching:", query);
            return 0;
        }

        xmz::println("Search Results for '", query, "'");
        xmz::println("Found", results.size(), "package(s):");
        xmz::println("");
        int count = 1;
        for (const auto& result : results) {
            xmz::println(count, ". ", result.name);
            xmz::println("   Package: ", result.package);
            xmz::println("   Version: ", result.version);
            xmz::println("   Description: ", result.description);
            xmz::println("   Repository: ", result.repo);
            xmz::println("   Status: ", result.is_installed ? "[INSTALLED]" : "[NOT INSTALLED]");
            xmz::println("");
            count++;
        }
        return 0;
    }

    inline int search_package_detail(const std::string& query) {
        a1pm::config cfg;
        a1::ini::ini_parser pini;
        if (query.empty()) {
            xmz::log::error("Search query cannot be empty");
            return 1;
        }

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
        if (!xmz::aux::is_dir(cache_dir)) { xmz::fs::mkdir(cache_dir); }
        bool found = false;
        for (const auto& repo_url : sections) {
            std::string repo_name = url_to_repo_name(repo_url);
            std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
            if (!xmz::aux::is_file(metadata_file)) continue;
            a1::ini::ini_parser pkg_parser;
            if (!pkg_parser.parse_file(metadata_file)) continue;
            std::string version = pkg_parser.get(query, "version", "");
            if (!version.empty()) {
                found = true;
                std::string name            = pkg_parser.get(query, "name", query);
                std::string description     = pkg_parser.get(query, "description", "");
                std::string author          = pkg_parser.get(query, "author", "");
                std::string maintainer      = pkg_parser.get(query, "maintainer", "");
                std::string depends         = pkg_parser.get(query, "depends", "");
                std::string depends_apt     = pkg_parser.get(query, "depends_apt", "");
                std::string filepath        = pkg_parser.get(query, "filepath", "");
                std::string sha256          = pkg_parser.get(query, "sha256", "");
                std::string size            = pkg_parser.get(query, "size", "");
                bool is_installed = a1mod::g_module_db.modules.find(query) != a1mod::g_module_db.modules.end();
                xmz::println("Package Details");
                xmz::println("Package: ", query);
                xmz::println("Name: ", name);
                xmz::println("Version: ", version);
                xmz::println("Description: ", description);
                if (!author.empty())        xmz::println("Author: ", author);
                if (!maintainer.empty())    xmz::println("Maintainer: ", maintainer);
                if (!depends.empty())       xmz::println("Depends: ", depends);
                if (!depends_apt.empty())   xmz::println("System Depends: ", depends_apt);
                if (!size.empty())          xmz::println("Size: ", size);
                xmz::println("Repository: ", repo_url);
                xmz::println("Status: ", is_installed ? "INSTALLED" : "NOT INSTALLED");
                if (is_installed) {
                    auto it = a1mod::g_module_db.modules.find(query);
                    if (it != a1mod::g_module_db.modules.end()) {
                        xmz::println("Installed Location: ", it->second.install_base);
                        xmz::println("Installed Date: ", it->second.installed_date);
                    }
                }
                break;
            }
        }

        if (!found) {
            xmz::log::error("Package not found:", query);
            xmz::log::info("Try using 'search' to find similar packages");
            return 1;
        }
        return 0;
    }
} /* namespace a1pm */

