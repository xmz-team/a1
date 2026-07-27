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
        std::string a1config = a1_dir + "/config";
    };
} /* namespace a1::config */
