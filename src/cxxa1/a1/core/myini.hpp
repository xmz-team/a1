// myini.hpp
#ifndef A1_MYINI_HPP
#define A1_MYINI_HPP

#include <string>
#include <map>
#include <vector>
#include <libxmz/fs.hpp>
#include <libxmz/str.hpp>

namespace a1::ini {
class ini_parser {
public:
    bool parse_file(const std::string& filepath) {
        std::string content = xmz::fs::readfile_str(filepath);
        if (content.empty()) return false;
        return parse_str(content);
    }

    bool parse_str(const std::string& content) {
        data_.clear();
        std::string currentSection;
        auto lines = xmz::str::split(content, "\n");
        for (auto line : lines) {
            line = remove_comments(line);
            line = xmz::str::trim(line);
            if (line.empty()) continue;
            if (line[0] == '[' && line.back() == ']') {
                std::string sectionName = xmz::str::trim(
                    line.substr(1, line.size() - 2));
                sectionName = unescape_string(sectionName);
                currentSection = sectionName;
                data_.try_emplace(currentSection);
                continue;
            }
            auto pos_eq = line.find('=');
            auto pos_col = line.find(':');
            auto pos = std::string::npos;
            if (pos_eq != std::string::npos && pos_col != std::string::npos)
                pos = std::min(pos_eq, pos_col);
            else if (pos_eq != std::string::npos)
                pos = pos_eq;
            else if (pos_col != std::string::npos)
                pos = pos_col;

            if (pos != std::string::npos) {
                auto key = xmz::str::trim(line.substr(0, pos));
                auto val = xmz::str::trim(line.substr(pos + 1));
                key = unescape_string(key);
                val = unescape_string(val);
                if (!key.empty()) { data_[currentSection][key] = val; }
            }
        }
        return true;
    }

    std::string get(const std::string& sec,
                    const std::string& key,
                    const std::string& def = "") const {
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        const std::map<std::string, std::map<std::string, std::string>>* current = &data_;
        for (const auto& s : sections) {
            auto it = current->find(s);
            if (it == current->end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    auto ki = direct_it->second.find(key);
                    return ki != direct_it->second.end() ? ki->second : def;
                }
                return def;
            }
            current = &it->second;
            if (current->empty() || current->begin()->second.empty()) { if (&current == &it->second) break; }
        }
        if (!sections.empty()) {
            auto last_it = data_.find(sections.back());
            if (last_it == data_.end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    auto ki = direct_it->second.find(key);
                    return ki != direct_it->second.end() ? ki->second : def;
                }
            } else {
                auto ki = last_it->second.find(key);
                if (ki != last_it->second.end()) return ki->second;
            }
        }
        return def;
#else
        auto si = data_.find(sec);
        if (si == data_.end()) return def;
        auto ki = si->second.find(key);
        return ki != si->second.end() ? ki->second : def;
#endif
    }

    int get_int(const std::string& sec,
                const std::string& key,
                int def = 0) const {
        auto s = get(sec, key);
        if (s.empty()) return def;
        try { return std::stoi(s); }
        catch (...) { return def; }
    }

    bool get_bool(const std::string& sec,
                  const std::string& key,
                  bool def = false) const {
        auto s = get(sec, key);
        if (s.empty()) return def;
        return s == "true" || s == "1" || s == "yes" || s == "on";
    }

    std::vector<std::string> getSections() const {
        std::vector<std::string> out;
        for (auto& [k, _] : data_) out.push_back(k);
        return out;
    }

    inline std::vector<std::string> get_sec() const { return getSections(); }

    std::vector<std::string> get_key(const std::string& sec) const {
        std::vector<std::string> out;
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        const std::map<std::string, std::map<std::string, std::string>>* current = &data_;
        for (const auto& s : sections) {
            auto it = current->find(s);
            if (it == current->end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    for (auto& [k, _] : direct_it->second) out.push_back(k);
                    return out;
                }
                return out;
            }
            current = &it->second;
        }
        if (!sections.empty()) {
            auto last_it = data_.find(sections.back());
            if (last_it == data_.end()) {
                std::string full_path;
                for (size_t i = 0; i < sections.size(); ++i) {
                    if (i > 0) full_path += ".";
                    full_path += sections[i];
                }
                auto direct_it = data_.find(full_path);
                if (direct_it != data_.end()) {
                    for (auto& [k, _] : direct_it->second) out.push_back(k);
                }
            } else {
                for (auto& [k, _] : last_it->second) out.push_back(k);
            }
        }
        return out;
#else
        auto it = data_.find(sec);
        if (it != data_.end())
            for (auto& [k, _] : it->second) out.push_back(k);
        return out;
#endif
    }

    void clear() { data_.clear(); }

    bool save_cover(const std::string& filepath) const {
        std::string out;
        for (const auto& [sec, kv] : data_) {
            out += "[" + sec + "]\n";
            for (const auto& [k, v] : kv) { 
                out += escape_string(k) + "=" + escape_string(v) + "\n"; 
            }
        }
        return xmz::fs::writefile(out, filepath);
    }

    bool save_append(const std::string& filepath) const {
        std::string out;
        for (const auto& [sec, kv] : data_) {
            out += "[" + sec + "]\n";
            for (const auto& [k, v] : kv) { 
                out += escape_string(k) + "=" + escape_string(v) + "\n"; 
            }
        }
        return xmz::fs::append(out, filepath);
    }

    void set(const std::string& sec, const std::string& key, 
             const std::string& val) { 
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        std::string full_path;
        for (size_t i = 0; i < sections.size(); ++i) {
            if (i > 0) full_path += ".";
            full_path += sections[i];
        }
        data_[full_path][key] = val;
#else
        data_[sec][key] = val;
#endif
    }

    void set_int(const std::string& sec, const std::string& key, int val) { set(sec, key, std::to_string(val)); }

    void set_bool(const std::string& sec, const std::string& key, bool val) { set(sec, key, val ? "true" : "false"); }

    bool remove_key(const std::string& sec, const std::string& key) {
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        std::string full_path;
        for (size_t i = 0; i < sections.size(); ++i) {
            if (i > 0) full_path += ".";
            full_path += sections[i];
        }
        auto si = data_.find(full_path);
#else
        auto si = data_.find(sec);
#endif
        if (si != data_.end()) { return si->second.erase(key) > 0; }
        return false;
    }

    bool remove_section(const std::string& sec) { 
#ifdef A1_INI_EXPAND
        auto sections = split_path(sec);
        std::string full_path;
        for (size_t i = 0; i < sections.size(); ++i) {
            if (i > 0) full_path += ".";
            full_path += sections[i];
        }
        return data_.erase(full_path) > 0;
#else
        return data_.erase(sec) > 0;
#endif
    }

    bool rmkey(const std::string& sec, const std::string& key) { return remove_key(sec, key); }
    bool rmsec(const std::string& sec) { return remove_section(sec); }

    static std::string escape_string(const std::string& str) {
        std::string result;
        result.reserve(str.size() * 2);
        for (char c : str) {
            switch (c) {
                case '\n': result += "\\n"; break;
                case '\r': result += "\\r"; break;
                case '\t': result += "\\t"; break;
                case '\v': result += "\\v"; break;
                case '\f': result += "\\f"; break;
                case '\b': result += "\\b"; break;
                case '\\': result += "\\\\"; break;
                case '\"': result += "\\\""; break;
                case '\'': result += "\\'"; break;
                case ';': result += "\\;"; break;
                case '#': result += "\\#"; break;
                default: result += c; break;
            }
        }
        return result;
    }

    static std::string unescape_string(const std::string& str) {
        std::string result;
        result.reserve(str.size());
        for (size_t i = 0; i < str.size(); ++i) {
            if (str[i] == '\\' && i + 1 < str.size()) {
                char next = str[i + 1];
                switch (next) {
                    case 'n': result += '\n'; ++i; break;
                    case 'r': result += '\r'; ++i; break;
                    case 't': result += '\t'; ++i; break;
                    case 'v': result += '\v'; ++i; break;
                    case 'f': result += '\f'; ++i; break;
                    case 'b': result += '\b'; ++i; break;
                    case '\\': result += '\\'; ++i; break;
                    case '\"': result += '\"'; ++i; break;
                    case '\'': result += '\''; ++i; break;
                    case ';': result += ';'; ++i; break;
                    case '#': result += '#'; ++i; break;
                    default: result += str[i]; break;
                }
            } else {
                result += str[i];
            }
        }
        return result;
    }

    static std::string remove_comments(const std::string& line) {
        bool in_quotes = false;
        bool escape_next = false;
        std::string result;
        for (size_t i = 0; i < line.size(); ++i) {
            char c = line[i];
            if (escape_next) {
                result += c;
                escape_next = false;
                continue;
            }
            if (c == '\\') {
                if (i + 1 < line.size()) {
                    char next = line[i + 1];
                    if (next == ';' || next == '#') {
                        result += c;
                        result += next;
                        ++i;
                        continue;
                    }
                }
                escape_next = true;
                result += c;
                continue;
            }
            if (c == '"') {
                in_quotes = !in_quotes;
                result += c;
                continue;
            }
            if (!in_quotes && (c == ';' || c == '#')) { return result; }
            result += c;
        }
        return result;
    }
private:
    std::map<std::string, std::map<std::string, std::string>> data_;
#ifdef A1_INI_EXPAND
    static std::vector<std::string> split_path(const std::string& path) {
        std::vector<std::string> parts;
        size_t start = 0;
        size_t end = path.find('.');
        while (end != std::string::npos) {
            parts.push_back(path.substr(start, end - start));
            start = end + 1;
            end = path.find('.', start);
        }
        parts.push_back(path.substr(start));
        return parts;
    }
#endif
};
} /* namespace a1::ini */
#endif /* A1_MYINI_HPP */
