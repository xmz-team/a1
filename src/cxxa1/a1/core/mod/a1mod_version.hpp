// a1mod_version.hpp
#pragma once
#include <string>
#include <vector>
#include <regex>
#include <algorithm>
#include <cctype>

namespace a1mod {
namespace version {
struct parsed_version {
    int epoch;
    std::string upstream;
    std::string revision;
    parsed_version() : epoch(0) {}
};

// split version string by delimiters
inline std::vector<std::string> split_version(const std::string& str, const std::string& delims) {
    std::vector<std::string> parts;
    size_t start = 0;
    size_t end = 0;
    while ((end = str.find_first_of(delims, start)) != std::string::npos) {
        if (end > start) { parts.push_back(str.substr(start, end - start)); }
        parts.push_back(str.substr(end, 1));
        start = end + 1;
    }
    if (start < str.length()) { parts.push_back(str.substr(start)); }
    return parts;
}

// check if character is digit
inline bool is_digit(char c) { return c >= '0' && c <= '9'; }
// check if character is letter
inline bool is_letter(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
inline int compare_version_strings(const std::string& a, const std::string& b) {
    size_t i = 0, j = 0;
    while (i < a.length() || j < b.length()) {
        int first_diff = 0;
        while ((i < a.length() && !is_digit(a[i])) || (j < b.length() && !is_digit(b[j]))) {
            int ac = (i < a.length()) ? (int)a[i] : 0;
            int bc = (j < b.length()) ? (int)b[j] : 0;
            if (ac != bc) {
                if (ac == '~') return -1;
                if (bc == '~') return 1;
                if (is_letter(ac) && !is_letter(bc)) return -1;
                if (!is_letter(ac) && is_letter(bc)) return 1;
                return ac - bc;
            }
            if (ac) i++;
            if (bc) j++;
        }
        while (i < a.length() && a[i] == '0') i++;
        while (j < b.length() && b[j] == '0') j++;
        size_t start_i = i;
        size_t start_j = j;
        while (i < a.length() && is_digit(a[i])) i++;
        while (j < b.length() && is_digit(b[j])) j++;
        size_t len_i = i - start_i;
        size_t len_j = j - start_j;
        if (len_i != len_j) { return len_i < len_j ? -1 : 1; }
        for (size_t k = 0; k < len_i; k++) { if (a[start_i + k] != b[start_j + k]) { return a[start_i + k] < b[start_j + k] ? -1 : 1; } }
    }
    return 0;
}

// parse version string into epoch, upstream, revision
inline parsed_version parse(const std::string& version) {
    parsed_version pv;
    std::string ver = version;
    size_t colon_pos = ver.find(':');
    if (colon_pos != std::string::npos) {
        std::string epoch_str = ver.substr(0, colon_pos);
        try { pv.epoch = std::stoi(epoch_str); } catch (...) { pv.epoch = 0; }
        ver = ver.substr(colon_pos + 1);
    }
    size_t last_dash = ver.rfind('-');
    if (last_dash != std::string::npos) {
        std::string after_dash = ver.substr(last_dash + 1);
        bool is_numeric = !after_dash.empty() && 
                         std::all_of(after_dash.begin(), after_dash.end(), ::isdigit);
        if (is_numeric) {
            pv.revision = after_dash;
            ver = ver.substr(0, last_dash);
        }
    }
    pv.upstream = ver;
    return pv;
}

inline int compare(const std::string& ver_a, const std::string& ver_b) {
    parsed_version a = parse(ver_a);
    parsed_version b = parse(ver_b);
    // compare epochs
    if (a.epoch != b.epoch) { return a.epoch < b.epoch ? -1 : 1; }
    // compare upstream versions
    int cmp = compare_version_strings(a.upstream, b.upstream);
    if (cmp != 0) return cmp;
    // compare revisions (numeric comparison if both exist)
    if (!a.revision.empty() || !b.revision.empty()) {
        int rev_a = 0, rev_b = 0;
        try { if (!a.revision.empty()) rev_a = std::stoi(a.revision); } catch (...) { rev_a = 0; }
        try { if (!b.revision.empty()) rev_b = std::stoi(b.revision); } catch (...) { rev_b = 0; }
        if (rev_a != rev_b) { return rev_a < rev_b ? -1 : 1; }
    }
    return 0;
}

// check if version matches constraint
// supports: >=, <=, >, <, =, ==, !=
inline bool satisfies(const std::string& version, const std::string& constraint) {
    if (constraint.empty()) return true;
    std::string op;
    std::string ver;
    if (constraint.length() >= 2) {
        std::string prefix = constraint.substr(0, 2);
        if (prefix == ">=" || prefix == "<=" || prefix == "==" || prefix == "!=") {
            op = prefix;
            ver = constraint.substr(2);
        }
    }
    if (op.empty() && !constraint.empty()) {
        if (constraint[0] == '>' || constraint[0] == '<' || constraint[0] == '=') {
            op = constraint.substr(0, 1);
            ver = constraint.substr(1);
        }
    }
    if (op.empty()) {
        op = ">=";
        ver = constraint;
    }
    ver.erase(0, ver.find_first_not_of(" \t"));
    ver.erase(ver.find_last_not_of(" \t") + 1);
    int cmp = compare(version, ver);
    if (op == ">=" || op == ">") {
        return op == ">=" ? cmp >= 0 : cmp > 0;
    } else if (op == "<=" || op == "<") {
        return op == "<=" ? cmp <= 0 : cmp < 0;
    } else if (op == "==" || op == "=") {
        return cmp == 0;
    } else if (op == "!=") {
        return cmp != 0;
    }
    return false;
}

// check if version is in range: ">=1.0,<2.0"
inline bool in_range(const std::string& version, const std::string& range) {
    if (range.empty()) return true;
    auto parts = xmz::str::split(range, ",");
    for (auto& part : parts) {
        part = xmz::str::trim(part);
        if (!part.empty() && !satisfies(version, part)) { return false; }
    }
    return true;
}

} // namespace version
} // namespace a1mod
