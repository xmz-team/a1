// config.hpp
#pragma once
#include <string>
#include <libxmz/io.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/log.hpp>
#include <a1/core/myini.hpp>
#include <cstdlib>

namespace a1::config {
    class jb_path {
    public:
        std::string jb = std::getenv("jb");
        std::string a1_dir = jb + "/a1";
        std::string core_config_dir = a1_dir + "/core_config";
        std::string a1config = a1_dir + "/configs";
        std::string a1_script = jb + "/usr/local/bin/a1";
        std::string 
a1_return_script = jb + "/usr/local/bin/a1-return";
        std::string a1ctl_script = jb + "/usr/local/bin/a1ctl";
        std::string config_dir = a1config;
        std::string backup_dir = a1_dir + "/backup";
        std::string bak_d = backup_dir;
        std::string high_f = a1_dir + "/high_priority.list";
        std::string low_f = a1_dir + "/low_priority.list";
        std::string custom_f = a1_dir + "/custom_priority.list";
    };
} /* namespace a1::config */
