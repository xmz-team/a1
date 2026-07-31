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
            line = xmz::str::trim(line);
            if (line.empty() || line[0] == ';' || line[0] == '#') continue;
            
            if (line[0] == '[' && line.back() == ']') {
                currentSection = xmz::str::trim(
                    line.substr(1, line.size() - 2));
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
                if (!key.empty()) {
                    data_[currentSection][key] = val;
                }
            }
        }
        return true;
    }

    std::string get(const std::string& sec,
                    const std::string& key,
                    const std::string& def = "") const {
        auto si = data_.find(sec);
        if (si == data_.end()) return def;
        auto ki = si->second.find(key);
        return ki != si->second.end() ? ki->second : def;
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

    std::vector<std::string> get_key(const std::string& sec) const {
        std::vector<std::string> out;
        auto it = data_.find(sec);
        if (it != data_.end())
            for (auto& [k, _] : it->second) out.push_back(k);
        return out;
    }

    void clear() { data_.clear(); }

    bool save(const std::string& filepath) const {
        std::string out;
        for (const auto& [sec, kv] : data_) {
            out += "[" + sec + "]\n";
            for (const auto& [k, v] : kv) { out += k + "=" + v + "\n"; }
        }
        return xmz::fs::writefile(out, filepath);
    }

    void set(const std::string& sec, const std::string& key, 
         const std::string& val) { data_[sec][key] = val; }

    void set_int(const std::string& sec, const std::string& key, int val) { data_[sec][key] = std::to_string(val); }

    void set_bool(const std::string& sec, const std::string& key, bool val) { data_[sec][key] = val ? "true" : "false"; }

    bool remove_key(const std::string& sec, const std::string& key) {
        auto si = data_.find(sec);
        if (si != data_.end()) { return si->second.erase(key) > 0; }
        return false;
    }

    bool remove_section(const std::string& sec) { return data_.erase(sec) > 0; }

    bool rmkey(const std::string& sec, const std::string& key) { return remove_key(sec, key); }
    bool rmsec(const std::string& sec) { return remove_section(sec); }

private:
    std::map<std::string, std::map<std::string, std::string>> data_;
};

} /* namespace a1::ini */
#endif /* A1_MYINI_HPP */
