// a1gui_config.hpp
#pragma once
#include <string>
#include <cstdlib>

namespace a1::config {
    class jb_path {
    public:
        std::string jb;
        std::string a1_dir;
        std::string a1config;
        std::string a1_script;
        std::string a1_return_script;
        std::string a1ctl_script;
        std::string config_dir;
        std::string backup_dir;
        std::string bak_d;
        std::string high_f;
        std::string low_f;
        std::string custom_f;
        std::string mod_dir;
        std::string mod_cfg;
        std::string mod_list;
        jb_path() = default;
        void init() {
            jb = get_jb();
            a1_dir = jb + "/a1";
            a1config = a1_dir + "/configs";
            a1_script = jb + "/usr/local/bin/a1";
            a1_return_script = jb + "/usr/local/bin/a1-return";
            a1ctl_script = jb + "/usr/local/bin/a1ctl";
            config_dir = a1config;
            backup_dir = a1_dir + "/backup";
            bak_d = backup_dir;
            high_f = a1_dir + "/high_priority.list";
            low_f = a1_dir + "/low_priority.list";
            custom_f = a1_dir + "/custom_priority.list";
            mod_dir = a1_dir + "/modules";
            mod_cfg = mod_dir + "/config.ini";
            mod_list = mod_dir + "/module.list.ini";
        }
    private:
        std::string get_jb() { const char *v = std::getenv("jb"); return v ? v : ""; }
};
} /* namespace a1::config */
