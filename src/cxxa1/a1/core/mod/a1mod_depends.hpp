// a1mod_depends.hpp
#pragma once
#include <string>
#include <vector>
#include <set>
#include <queue>
#include <algorithm>
#include <regex>
#include <functional>

#include <libxmz/log.hpp>
#include <libxmz/str.hpp>

#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>
#include <a1/core/mod/a1mod_version.hpp>

namespace a1mod {
namespace depends {

struct dep_info {
    std::string name;
    std::string version_constraint;
    bool optional;
};

struct dep_node {
    std::string name;
    std::string version;
    std::vector<dep_info> deps;
    bool installed;
    bool visited;
    bool in_stack;
    //bool optional;
};

// "mod1(>=1.0), mod2(<=2.0)"
// "mod1>=1.0, mod2<=2.0"
// "mod1 (>= 1.0) , mod2 (<= 2.0)"
// "mod1 | mod2" (alternatives)
inline std::vector<dep_info> parse_depends(const std::string& dep_str) {
    std::vector<dep_info> result;
    if (dep_str.empty()) return result;
    auto parts = xmz::str::split(dep_str, ",");
    for (auto& part : parts) {
        part = xmz::str::trim(part);
        if (part.empty()) continue;
        dep_info info;
        info.optional = false;
        size_t alt_pos = part.find('|');
        if (alt_pos != std::string::npos) {
            info.optional = true;
            part = part.substr(0, alt_pos);
            part = xmz::str::trim(part);
        }
        std::regex paren_regex(R"(^([a-zA-Z0-9_\-\.]+)\s*\(\s*([<>=!]+\s*[a-zA-Z0-9_\-\.\+\~]+)\s*\))");
        std::smatch match;
        if (std::regex_search(part, match, paren_regex)) {
            info.name = match[1].str();
            info.version_constraint = xmz::str::trim(match[2].str());
        } else {
            const std::vector<std::string> ops = {">=", "<=", "==", "!=", ">", "<", "="};
            size_t op_pos = std::string::npos;
            std::string found_op;
            for (const auto& op : ops) {
                size_t pos = part.find(op);
                if (pos != std::string::npos && pos > 0) {
                    if (op_pos == std::string::npos || pos < op_pos) {
                        op_pos = pos;
                        found_op = op;
                        break;
                    }
                }
            }
            if (op_pos != std::string::npos) {
                info.name = xmz::str::trim(part.substr(0, op_pos));
                info.version_constraint = xmz::str::trim(part.substr(op_pos));
            } else {
                info.name = part;
            }
        }
        info.name = xmz::str::trim(info.name);
        result.push_back(info);
    }
    return result;
}

inline bool check_dep_satisfied(
    const dep_info& dep, 
    const std::map<std::string, std::string>& installed) {
    auto it = installed.find(dep.name);
    if (it == installed.end()) { return dep.optional; }
    if (dep.version_constraint.empty()) { return true; }
    return version::satisfies(it->second, dep.version_constraint);
}

inline bool resolve_deps(
    const std::string& module_name,
    const std::map<std::string, dep_node>& available,
    const std::map<std::string, std::string>& installed,
    std::vector<std::string>& resolved,
    std::vector<std::string>& missing,
    std::vector<std::string>& conflicts) {
    std::map<std::string, dep_node> working = available;
    std::set<std::string> visited;
    std::set<std::string> in_stack;
    std::vector<std::string> order;
    std::function<bool(const std::string&)> dfs = 
    [&](const std::string& name) -> bool {
        if (in_stack.count(name)) {
            xmz::log::error("circular dependency detected:", name);
            conflicts.push_back(name);
            return false;
        }
        if (visited.count(name)) return true;
        auto it = working.find(name);
        if (it == working.end()) {
            // check if already installed
            if (installed.count(name)) {
                visited.insert(name);
                return true;
            }
            missing.push_back(name);
            return false;
        }
        in_stack.insert(name);
        for (const auto& dep : it->second.deps) {
            if (dep.optional) continue;
            if (!dfs(dep.name)) {
                auto inst_it = installed.find(dep.name);
                if (inst_it != installed.end() && version::satisfies(inst_it->second, dep.version_constraint)) { continue; }
                return false;
            }
        }
        in_stack.erase(name);
        visited.insert(name);
        order.push_back(name);
        return true;
    };
    if (!dfs(module_name)) { return false; }
    resolved = order;
    return true;
}

inline bool validate_deps(
    const std::vector<dep_info>& deps,
    const std::map<std::string, std::string>& installed) {
    for (const auto& dep : deps) {
        if (dep.optional) continue;
        if (!check_dep_satisfied(dep, installed)) {
            xmz::log::error("dependency not satisfied:", dep.name, dep.version_constraint);
            return false;
        }
    }
    return true;
}
} // namespace depends
} // namespace a1mod
