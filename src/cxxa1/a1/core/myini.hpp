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

    bool readfile(const std::string& filepath) { return parse_file(filepath); }

    bool parse_str(const std::string& content) {
        data_.clear();
        std::string currentSection;
        auto lines = xmz::str::split(content, "\n");
        for (auto line : lines) {
            line = remove_comments(line);
            line = xmz::str::trim(line);
            if (line.empty()) continue;
            if (line[0] == '[' && line.back() == ']') {
                std::string sectionName = xmz::str::trim(line.substr(1, line.size() - 2));
                sectionName = unescape_string(sectionName);
                currentSection = sectionName;
                data_.try_emplace(currentSection);
                continue;
            }
            auto pos_eq = line.find('=');
            auto pos_col = line.find(':');
            auto pos = std::string::npos;
            if (pos_eq != std::string::npos && pos_col != std::string::npos) pos = std::min(pos_eq, pos_col);
            else if (pos_eq != std::string::npos) pos = pos_eq;
            else if (pos_col != std::string::npos) pos = pos_col;

            if (pos != std::string::npos) {
                auto key = xmz::str::trim(line.substr(0, pos));
                auto val = xmz::str::trim(line.substr(pos + 1));
                key = unescape_string(key);
                val = unescape_string(val);
                if (!key.empty()) data_[currentSection][key] = val;
            }
        }
        return true;
    }

    bool readstr(const std::string& content) { return parse_file(content); }

    std::string get(const std::string& sec, const std::string& key, const std::string& def = "") const {
        auto si = data_.find(sec);
        if (si == data_.end()) return def;
        auto ki = si->second.find(key);
        return ki != si->second.end() ? ki->second : def;
    }

    int get_int(const std::string& sec, const std::string& key, int def = 0) const {
        auto s = get(sec, key);
        if (s.empty()) return def;
        try { return std::stoi(s); } catch (...) { return def };
    }

    bool get_bool(const std::string& sec, const std::string& key, bool def = false) const {
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
        auto it = data_.find(sec);
        if (it != data_.end()) for (auto& [k, _] : it->second) out.push_back(k);
        return out;
    }

    void clear() { data_.clear(); }

    bool save_cover(const std::string& filepath) const {
        std::string out;
        for (const auto& [sec, kv] : data_) {
            out += "[" + sec + "]\n";
            for (const auto& [k, v] : kv) out += escape_string(k) + "=" + escape_string(v) + "\n"; 
        }
        return xmz::fs::writefile(out, filepath);
    }

    bool save_append(const std::string& filepath) const {
        std::string out;
        for (const auto& [sec, kv] : data_) {
            out += "[" + sec + "]\n";
            for (const auto& [k, v] : kv) out += escape_string(k) + "=" + escape_string(v) + "\n"; 
        }
        return xmz::fs::append(out, filepath);
    }

    void set(const std::string& sec, const std::string& key, const std::string& val) { data_[sec][key] = val; }
    void set_int(const std::string& sec, const std::string& key, int val) { set(sec, key, std::to_string(val)); }
    void set_bool(const std::string& sec, const std::string& key, bool val) { set(sec, key, val ? "true" : "false"); }

    bool remove_key(const std::string& sec, const std::string& key) {
        auto si = data_.find(sec);
        if (si != data_.end()) return si->second.erase(key) > 0;
        return false;
    }

    bool remove_section(const std::string& sec) { return data_.erase(sec) > 0; }
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
            if (!in_quotes && (c == ';' || c == '#')) return result;
            result += c;
        }
        return result;
    }
private:
    std::map<std::string, std::map<std::string, std::string>> data_;
};
} /* namespace a1::ini */
#endif /* A1_MYINI_HPP */
