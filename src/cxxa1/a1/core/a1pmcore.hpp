// a1pmcore.hpp
#pragma once

#include <string>
#include <regex>
#include <algorithm>
#include <set>
#include <filesystem>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/time.hpp>

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
		if (!result.empty() && result.back() == '/') { result.pop_back(); }
		std::replace(result.begin(), result.end(), '/', '_');
		return result;
	}

	inline void init_repo_list() {
		a1pm::config pmcfg;
		if (xmz::aux::is_file(pmcfg.repo_f) == 1) { xmz::fs::writefile(pmcfg.repo_default_cfg, pmcfg.repo_f); }
		if (xmz::aux::is_dir(pmcfg.pm_cache) == 1) { xmz::fs::mkdir(pmcfg.pm_cache); }
	}

	inline int add_repo(const std::string& url) {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (url == "") {
			xmz::log::error("the url cannot be empty");
			return 1;
		}

		std::string name = url_to_repo_name(url);
		pini.parse_file(cfg.repo_f);
		if (pini.get(url, url) != "") {
			xmz::log::warn("Repo:", url, "already exists, will update the time");
			std::string time = xmz::get_time_str();
			pini.set(url, "last_sync", time);
			xmz::println("already exists, updated last_sync");
		} else {
			std::string time = xmz::get_time_str();
			std::string repo_text = "[" + url + "]\n",
"url: " + url + "\n",
"last_sync: " + time + "\n";
			xmz::writefile(repo_text, cfg.repo_f);
			xmz::println("added successfully");
		}
	}

	inline int remove_repo(const std::string& url) {
		a1pm::config cfg;
		a1::ini::ini_parser pini;
		if (url != "") {
			pini.parse_file(cfg.repo_f);
			pini.rmkey(url, last_sync);
			pini.rmkey(url, url);
			pini.rmsec(url);
			xmz::log::info("Repo:", url, "deleted");
		} else {
			xmz::log::error("the url cannot be empty");
		}
	}

	namespace aux {
		inline int install_package_with_deps(
			const std::string& package, 
			std::set<std::string>& installed,
			std::set<std::string>& visiting) {
			a1pm::config cfg;
			a1::ini::ini_parser pini;
			if (installed.find(package) != installed.end()) { return 0; }
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
			if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
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
				if (xmz::aux::is_file(metadata_file) != 0) {
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
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									pos = dep_name.find('>');
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									pos = dep_name.find('<');
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									pos = dep_name.find('=');
									if (pos != std::string::npos) { dep_name = xmz::str::trim(dep_name.substr(0, pos)); }
									if (!dep_name.empty()) { pkg_depends.push_back(dep_name); }
								}
							}
						}
					 std::string depends_apt_str = pkg_parser.get(pkg_name, "depends_apt", "");
						if (!depends_apt_str.empty()) {
							auto parts = xmz::str::split(depends_apt_str, ",");
							for (auto& p : parts) {
								p = xmz::str::trim(p);
								if (!p.empty()) { pkg_depends_apt.push_back(p); }
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
					auto result = xmz::cmd::run_shell_capture(
						"dpkg -l " + apt_pkg + " 2>/dev/null | grep '^ii'"
					);
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
			std::string cache_filename = pkg_filename.empty() ? 
				std::filesystem::path(pkg_filepath).filename().string() : pkg_filename;
			std::string download_cache = cache_dir + "/downloads/" + cache_filename;
			if (xmz::aux::is_dir(cache_dir + "/downloads") == 1) { xmz::fs::mkdir(cache_dir + "/downloads"); }
			xmz::log::info("Installing package:", package);
			xmz::println("	Version:", pkg_version);
			xmz::println("	From:", found_repo);
			xmz::println("	URL:", download_url);
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
					xmz::println("	Expected:", pkg_sha256);
					xmz::println("	Actual:  ", sha256_actual);
					xmz::fs::rm(download_cache);
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
	inline int install_package(const std::string& package) {
		std::set<std::string> installed;
		std::set<std::string> visiting;
		for (const auto& [name, entry] : a1mod::g_module_db.modules) { installed.insert(name); }
		return aux::install_package_with_deps(package, installed, visiting);
	}

	inline void remove_package(const std::string& package) { return a1mod::remove(package); }

	inline void list_repos() {
		a1pm::config cfg;
		//a1::ini::ini_parser pini;
		xmz::println("current source list");
		xmz::fs::readfile(cfg.repo_f);
	}

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
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }

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
			if (xmz::aux::is_file(metadata_file) != 0) {
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
				std::string descr_msg = pkg_parser.get(pkg_name, "descr", "");
				if (description.empty()) { description = descr_msg; }
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
					result.is_installed = a1mod::g_module_db.modules.find(pkg_name) != 
										  a1mod::g_module_db.modules.end();
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
			xmz::println("	 Package: ", result.package);
			xmz::println("	 Version: ", result.version);
			xmz::println("	 Description: ", result.description);
			xmz::println("	 Repository: ", result.repo);
			xmz::println("	 Status: ", result.is_installed ? "[INSTALLED]" : "[NOT INSTALLED]");
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
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
		bool found = false;
		for (const auto& repo_url : sections) {
			std::string repo_name = url_to_repo_name(repo_url);
			std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
			if (xmz::aux::is_file(metadata_file) != 0) { continue; }
			a1::ini::ini_parser pkg_parser;
			if (!pkg_parser.parse_file(metadata_file)) { continue; }
			std::string version = pkg_parser.get(query, "version", "");
			if (!version.empty()) {
				found = true;
				std::string name = pkg_parser.get(query, "name", query);
				std::string description = pkg_parser.get(query, "description", "");
				if (description.empty()) { description = pkg_parser.get(query, "descr", ""); }
				std::string author = pkg_parser.get(query, "author", "");
				std::string maintainer = pkg_parser.get(query, "maintainer", "");
				std::string depends = pkg_parser.get(query, "depends", "");
				std::string depends_apt = pkg_parser.get(query, "depends_apt", "");
				std::string filepath = pkg_parser.get(query, "filepath", "");
				std::string sha256 = pkg_parser.get(query, "sha256", "");
				std::string size = pkg_parser.get(query, "size", "");
				bool is_installed = a1mod::g_module_db.modules.find(query) != 
									a1mod::g_module_db.modules.end();
				xmz::println("Package Details");
				xmz::println("Package: ", query);
				xmz::println("Name: ", name);
				xmz::println("Version: ", version);
				xmz::println("Description: ", description);
				if (!author.empty()) { xmz::println("Author: ", author); }
				if (!maintainer.empty()) { xmz::println("Maintainer: ", maintainer); }
				if (!depends.empty()) { xmz::println("Depends: ", depends); }
				if (!depends_apt.empty()) { xmz::println("System Depends: ", depends_apt); }
				if (!size.empty()) { xmz::println("Size: ", size); }
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

	inline int update_repo(const std::string& repo_url) {
		a1pm::config cfg;
		if (repo_url.empty()) {
			xmz::log::error("Repository URL cannot be empty");
			return 1;
		}
		std::string repo_name = url_to_repo_name(repo_url);
		std::string cache_dir = cfg.pm_cache;
		std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
		std::string metadata_url = repo_url;
		if (metadata_url.back() != '/') { metadata_url += "/"; }
		metadata_url += "Packages.ini";
		xmz::log::info("Updating repository:", repo_url);
		xmz::println("	URL:", metadata_url);
		std::string error_msg;
		if (!a1pm::curl::download_file(metadata_url, metadata_file, error_msg)) {
			xmz::log::error("Failed to update repository:", error_msg);
			return 1;
		}
		a1::ini::ini_parser parser;
		if (!parser.parse_file(metadata_file)) {
			xmz::log::error("Invalid metadata file:", metadata_file);
			xmz::fs::rm(metadata_file);
			return 1;
		}
		a1::ini::ini_parser repo_parser;
		repo_parser.parse_file(cfg.repo_f);
		std::string time = xmz::get_time_str();
		repo_parser.set(repo_url, "last_sync", time);
		repo_parser.save(cfg.repo_f);
		auto packages = parser.get_sec();
		xmz::log::info("Repository updated successfully");
		xmz::println("	Packages:", packages.size());
		xmz::println("	Last sync:", time);
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
			if (update_repo(repo_url) == 0) { success_count++; } else { fail_count++; }
			xmz::println("");
		}
		xmz::log::info("Update completed");
		xmz::println("	Successful:", success_count);
		xmz::println("	Failed:", fail_count);
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
		if (xmz::aux::is_dir(cache_dir) == 1) { xmz::fs::mkdir(cache_dir); }
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
				if (xmz::aux::is_file(metadata_file) != 0) { continue; }
				a1::ini::ini_parser pkg_parser;
				if (!pkg_parser.parse_file(metadata_file)) { continue; }
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
			xmz::println("	", update.package);
			xmz::println("	  Current version:", update.current_version);
			xmz::println("	  New version:	  ", update.new_version);
			xmz::println("	  Repository:	  ", update.repo);
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
		xmz::println("	Current version:", it->second.version);
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
		if (update_all_repos() != 0) {
			xmz::log::warn("Some repositories failed to update, continuing...");
		}

		xmz::log::info("Checking for package updates...");
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
		std::vector<std::string> packages_to_update;
		for (const auto& [pkg_name, entry] : a1mod::g_module_db.modules) {
			std::string current_version = entry.version;
			bool has_update = false;
			for (const auto& repo_url : sections) {
				std::string repo_name = url_to_repo_name(repo_url);
				std::string metadata_file = cache_dir + "/" + repo_name + "_Packages.ini";
				if (xmz::aux::is_file(metadata_file) != 0) { continue; }
				a1::ini::ini_parser pkg_parser;
				if (!pkg_parser.parse_file(metadata_file)) { continue; }
				std::string version = pkg_parser.get(pkg_name, "version", "");
				if (!version.empty() && a1mod::version::compare(version, current_version) > 0) {
					has_update = true;
					break;
				}
			}

			if (has_update) { packages_to_update.push_back(pkg_name); }
		}

		if (packages_to_update.empty()) {
			xmz::println("All packages are up to date!");
			return 0;
		}

		xmz::println("Found", packages_to_update.size(), "package(s) to update:");
		for (const auto& pkg : packages_to_update) { xmz::println("	-", pkg); }
		xmz::println("");
		int success_count = 0;
		int fail_count = 0;
		for (const auto& pkg : packages_to_update) {
			if (update_package(pkg) == 0) { success_count++; } else { fail_count++; }
			xmz::println("");
		}
		xmz::log::info("Update completed");
		xmz::println("	Successful:", success_count);
		xmz::println("	Failed:", fail_count);
		return fail_count > 0 ? 1 : 0;
	}

	inline int update(const std::string& target = "") { if (target.empty()) { return update_all_packages(); } else { if (target.find("http://") == 0 || target.find("https://") == 0) { return update_repo(target); } else { return update_package(target); } } }

} /* namespace a1pm */

