// a1mod_config.hpp
#pragma once
#include <string>
#include <vector>
#include <map>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/str.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

namespace a1mod {
struct packinfo {
    /* necessary */
    std::string package;
    std::string name;
    std::string version;
    std::string descr;
    std::vector<std::string> maintainer;
    /* optional */
    std::vector<std::string> auther;
    std::vector<std::string> depends;
    std::vector<std::string> depends_apt;
    std::vector<std::string> section;
    bool is_valid() const {
        return !package.empty() && 
               !maintainer.empty() && 
               !version.empty() && 
               !descr.empty();
    }
    std::vector<std::string> get_miss_fields() const {
        std::vector<std::string> miss;
        if (package.empty()) miss.push_back("package");
        if (maintainer.empty()) miss.push_back("maintainer");
        if (version.empty()) miss.push_back("version");
        if (descr.empty()) miss.push_back("descr_msg.descr");
        return miss;
    }
};

// module database entry
struct module_entry {
    std::string name;
    std::string package;  // Added for consistency
    std::string author;
    std::string maintainer;
    std::string version;
    std::string description;
    std::string path;
    std::string install_base;
    std::string installed_date;
    std::string last_updated;
    std::vector<std::string> depends;
    std::vector<std::string> depends_apt;
    std::vector<std::string> update_log;
};

inline packinfo parse_packinfo(const a1::ini::ini_parser& parser) {
    packinfo info;
    
    info.package = parser.get("", "package");
    info.name = parser.get("", "name", info.package);
    info.version = parser.get("", "version");
    info.descr = parser.get("descr_msg", "descr");
    // parse maintainer
    std::string maintainer_str = parser.get("", "maintainer");
    if (!maintainer_str.empty()) {
        auto parts = xmz::str::split(maintainer_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.maintainer.push_back(p);
        }
    }
    // parse auther
    std::string auther_str = parser.get("", "auther", "");
    if (!auther_str.empty()) {
        auto parts = xmz::str::split(auther_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.auther.push_back(p);
        }
    }
    // parse section
    std::string section_str = parser.get("", "section", "");
    if (!section_str.empty()) {
        auto parts = xmz::str::split(section_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.section.push_back(p);
        }
    }
    // parse depends
    std::string depends_str = parser.get("", "depends", "");
    if (!depends_str.empty()) {
        auto parts = xmz::str::split(depends_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.depends.push_back(p);
        }
    }
    // parse apt depends
    std::string depends_apt_str = parser.get("", "depends_apt", "");
    if (!depends_apt_str.empty()) {
        auto parts = xmz::str::split(depends_apt_str, ",");
        for (auto& p : parts) {
            p = xmz::str::trim(p);
            if (!p.empty()) info.depends_apt.push_back(p);
        }
    }
    return info;
}

inline packinfo parse_packfile(const std::string& filepath) {
    a1::ini::ini_parser parser;
    if (!parser.parse_file(filepath)) { return packinfo{}; }
    return parse_packinfo(parser);
}

class config {
private:
    a1::config::jb_path g_jb;
public:
    std::string mod_install_tmp = g_jb.mod_dir + "/cache/temp";
    std::string users = g_jb.mod_dir + "/users";
    std::string authers = g_jb.mod_dir + "/official";
};

} // namespace a1mod
