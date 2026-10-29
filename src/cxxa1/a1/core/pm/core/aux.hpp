// aux.hpp
#pragma once

#include <string>
#include <vector>
#include <regex>
#include <algorithm>
#include <set>
#include <filesystem>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

#include <a1/core/a1modcore.hpp>
#include <a1/core/pm/a1pm_config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/pm/download.hpp>
#include <a1/core/pm/ssl.hpp>

namespace a1pm {
    inline std::string url_to_repo_name(const std::string& url) {
        std::string result = url;
        std::regex protocol_regex("^https?://");
        result = std::regex_replace(result, protocol_regex, "");
        if (!result.empty() && result.back() == '/') result.pop_back();
        std::replace(result.begin(), result.end(), '/', '_');
        return result;
    }

    inline void init_repo_list() {
        a1pm::config pmcfg;
        if (!xmz::aux::is_file(pmcfg.repo_f))  xmz::fs::writefile(pmcfg.repo_default_cfg, pmcfg.repo_f);
        if (!xmz::aux::is_dir(pmcfg.pm_cache)) xmz::fs::mkdir(pmcfg.pm_cache);
    }
    namespace aux {
        inline int install_package_with_deps(
            const std::string& package, 
            std::set<std::string>& installed,
            std::set<std::string>& visiting) {
            a1pm::config cfg;
            a1::ini::ini_parser pini;
            if (installed.find(package) != installed.end()) return 0;
            if (visiting.find(package) != visiting.end()) {
                xmz::log::error("Circular dependency detected:", package);
                return 1;
            }
            if (package.empty()) {
                xmz::log::error("package name cannot be empty");
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
            std::string found_repo;
            std::string pkg_filepath;
            std::string pkg_version;
            std::string pkg_sha256;
            std::string pkg_filename;
            std::vector<std::string> pkg_depends;
            std::vector<std::string> pkg_depends_apt;
            for (const auto& repo_url : sections) {
                std::string repo_name = url_to_repo_name(repo_url);
                std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
                if (!xmz::aux::is_file(metadata_file)) {
                    xmz::log::warn("Repository metadata not found:", repo_url);
                    continue;
                }
                a1::ini::ini_parser pkg_parser;
                if (!pkg_parser.parse_file(metadata_file)) {
                    xmz::log::warn("Failed to parse metadata for:", repo_url);
                    continue;
                }
                auto pkg_sections = pkg_parser.get_sec();
                for (const auto& pkg_name : pkg_sections) {
                    if (pkg_name == package) {
                        pkg_version = pkg_parser.get(pkg_name, "version", "");
                        pkg_filepath = pkg_parser.get(pkg_name, "filepath", "");
                        pkg_sha256 = pkg_parser.get(pkg_name, "sha256", "");
                        pkg_filename = pkg_parser.get(pkg_name, "filename", "");
                        std::string depends_str = pkg_parser.get(pkg_name, "depends", "");
                        if (!depends_str.empty()) {
                            auto parts = xmz::str::split(depends_str, ",");
                            for (auto& p : parts) {
                                p = xmz::str::trim(p);
                                if (!p.empty()) {
                                    std::string dep_name = p;
                                    size_t pos = dep_name.find('(');
                                    if (pos != std::string::npos) dep_name = xmz::str::trim(dep_name.substr(0, pos));
                                    pos = dep_name.find('>');
                                    if (pos != std::string::npos) dep_name = xmz::str::trim(dep_name.substr(0, pos));
                                    pos = dep_name.find('<');
                                    if (pos != std::string::npos) dep_name = xmz::str::trim(dep_name.substr(0, pos));
                                    pos = dep_name.find('=');
                                    if (pos != std::string::npos) dep_name = xmz::str::trim(dep_name.substr(0, pos));
                                    if (!dep_name.empty())        pkg_depends.push_back(dep_name);
                                }
                            }
                        }
                        std::string depends_apt_str = pkg_parser.get(pkg_name, "depends_apt", "");
                        if (!depends_apt_str.empty()) {
                            auto parts = xmz::str::split(depends_apt_str, ",");
                            for (auto& p : parts) {
                                p = xmz::str::trim(p);
                                if (!p.empty()) pkg_depends_apt.push_back(p);
                            }
                        }
                        if (pkg_version.empty() || pkg_filepath.empty()) {
                            xmz::log::warn("Package", package, "in", repo_url, "has incomplete metadata");
                            continue;
                        }
                        found_repo = repo_url;
                        break;
                    }
                }
                if (!found_repo.empty()) break;
            }
            if (found_repo.empty()) {
                xmz::log::error("Package not found:", package);
                return 1;
            }
            if (!pkg_depends_apt.empty()) {
                xmz::log::info("Checking system dependencies...");
                for (const auto& apt_pkg : pkg_depends_apt) {
                    auto result = xmz::cmd::run_shell_capture("dpkg -l " + apt_pkg + " 2>/dev/null | grep '^ii'");
                    if (result.exit_code != 0) {
                        xmz::log::error("Missing system package:", apt_pkg);
                        xmz::log::info("Install with: apt install", apt_pkg);
                        return 1;
                    }
                }
                xmz::log::info("System dependencies satisfied");
            }
            visiting.insert(package);
            if (!pkg_depends.empty()) {
                xmz::log::info("Installing dependencies for:", package);
                for (const auto& dep : pkg_depends) {
                    if (installed.find(dep) == installed.end()) {
                        xmz::log::info("  Dependency:", dep);
                        if (install_package_with_deps(dep, installed, visiting) != 0) {
                            xmz::log::error("Failed to install dependency:", dep);
                            visiting.erase(package);
                            return 1;
                        }
                    }
                }
            }
            std::string download_url = found_repo;
            if (download_url.back() != '/') { download_url += "/"; }
            download_url += pkg_filepath;
            std::string cache_filename = pkg_filename.empty() ? std::filesystem::path(pkg_filepath).filename().string() : pkg_filename;
            std::string download_cache = cache_dir + "/downloads/" + cache_filename;
            if (!xmz::aux::is_dir(cache_dir + "/downloads")) xmz::fs::mkdir(cache_dir + "/downloads");
            xmz::log::info("Installing package:", package);
            xmz::println("  Version:", pkg_version);
            xmz::println("  From:", found_repo);
            xmz::println("  URL:", download_url);
            std::string error_msg;
            if (!a1pm::curl::download_file(download_url, download_cache, error_msg)) {
                xmz::log::error("Download failed:", error_msg);
                return 1;
            }
            auto file_size = xmz::aux::get_file_size(download_cache);
            xmz::log::info("Download completed (", file_size, " bytes)");
            if (!pkg_sha256.empty()) {
                xmz::log::info("Verifying file integrity...");
                std::string sha256_actual = a1pm::ssl::get_file_hash_hex(download_cache);
                if (sha256_actual != pkg_sha256) {
                    xmz::log::error("SHA256 verification failed!");
                    xmz::println("  Expected:", pkg_sha256);
                    xmz::println("  Actual:  ", sha256_actual);
                    xmz::fs::recrmdir(download_cache);
                    visiting.erase(package);
                    return 1;
                }
                xmz::log::info("File integrity verified");
            }
            int install_result = a1mod::install(download_cache);
            xmz::fs::rmfile(download_cache);
            if (install_result == 0) {
                installed.insert(package);
                xmz::log::info("Package installed successfully:", package);
            }
            visiting.erase(package);
            return install_result;
        }
    } /* namespace aux */
} /* namespace a1pm */

