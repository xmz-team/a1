// priority_manager.hpp
#pragma once
#include <string>
#include <vector>
#include <map>

#include <a1/core/config.hpp>
#include <a1/core/get_sys_list.hpp>

#include <libxmz/str.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>

namespace a1 {
    // priority list read
    class priority_manager {
    public:
        void read_priority_lists(bool filter = false) {
            a1::config::jb_path g_jb;
            // empty the previous data
            high_priority_list_.clear();
            low_priority_list_.clear();
            custom_priority_list_.clear();
            // list of parsing systems
            auto system_high = xmz::str::split(a1::coreapi::lists::high, "\n");
            auto system_low = xmz::str::split(a1::coreapi::lists::low, "\n");
            // remove the blank line
            auto remove_empty = [](std::vector<std::string>& vec) { vec.erase(std::remove_if(vec.begin(), vec.end(), [](const std::string& s) { return s.empty(); }), vec.end()); };
            remove_empty(system_high);
            remove_empty(system_low);
            // read the high-priority list
            read_list_file(g_jb.a1_dir + "/high_priority.list", high_priority_list_, system_high, filter, true);
            // read the low-priority list
            read_list_file(g_jb.a1_dir + "/low_priority.list", low_priority_list_, system_low, filter, false);
            // read custom priority
            read_custom_list(g_jb.a1_dir + "/custom_priority.list");
        }
        const std::vector<std::string>& get_high_list() const { return high_priority_list_; }
        const std::vector<std::string>& get_low_list() const { return low_priority_list_; }
        const std::map<std::string, int>& get_custom_list() const { return custom_priority_list_; }
    private:
        std::vector<std::string> high_priority_list_;
        std::vector<std::string> low_priority_list_;
        std::map<std::string, int> custom_priority_list_;
        void read_list_file(const std::string& filepath, 
                            std::vector<std::string>& target_list,
                            const std::vector<std::string>& system_list,
                            bool filter, bool is_high_priority) {
            if (xmz::aux::is_file(filepath)) {
                std::string content = xmz::fs::readfile_str(filepath);
                auto lines = xmz::str::split(content, "\n");
                for (const auto& line : lines) {
                    std::string trimmed = xmz::str::trim(line);
                    if (trimmed.empty() || trimmed[0] == '#') continue;
                    if (filter) {
                        // check whether it is in the system list
                        bool is_system = std::find(system_list.begin(), system_list.end(), trimmed) != system_list.end();
                        if (is_high_priority && trimmed == "SpringBoard") target_list.push_back(trimmed); // SpringBoard always keeps
                        else if (!is_system) target_list.push_back(trimmed); // only non-system processes are added
                    } else {
                        target_list.push_back(trimmed);
                    }
                }
            } else {
                // the document does not exist
                if (!filter) target_list = system_list;  // use the system default list
                else if (is_high_priority) target_list = {"SpringBoard"};  // the filter mode only retains SpringBoard
            }
        }

        void read_custom_list(const std::string& filepath) {
            if (!xmz::aux::exist(filepath)) return;
            std::string content = xmz::fs::readfile_str(filepath);
            auto lines = xmz::str::split(content, "\n");
            for (const auto& line : lines) {
                std::string trimmed = xmz::str::trim(line);
                if (trimmed.empty() || trimmed[0] == '#') continue;
                auto parts = xmz::str::split(trimmed, "=");
                if (parts.size() >= 2) {
                    std::string process_name = xmz::str::trim(parts[0]);
                    std::string priority_str = xmz::str::trim(parts[1]);
                    int priority = 20;  // default value
                    if (!priority_str.empty()) try  { priority = std::stoi(priority_str); } catch (...) { priority = 20; }
                    custom_priority_list_[process_name] = priority;
                }
            }
        }
    };
} /* namespace a1 */
