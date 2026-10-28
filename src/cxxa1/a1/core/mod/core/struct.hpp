// struct.hpp
#pragma once
#include <string>
#include <vector>
#include <map>

#include <a1/core/mod/a1mod_config.hpp>

namespace a1mod {
    // module database
    struct module_db {
        std::map<std::string, module_entry> modules;
        std::vector<std::string>            enabled_modules;
        std::vector<std::string>            disabled_modules;
        std::string                         last_updated;
        bool is_enabled(const std::string& name) const  { return std::find(enabled_modules.begin(), enabled_modules.end(), name) != enabled_modules.end(); }
        bool is_disabled(const std::string& name) const { return std::find(disabled_modules.begin(), disabled_modules.end(), name) != disabled_modules.end(); }
    };
} /* namespace a1mod */
