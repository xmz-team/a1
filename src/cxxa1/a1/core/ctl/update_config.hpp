// update_config.hpp
#pragma once
#include <string>
#include <type_traits>

#include <a1/core/ctl/aux.hpp>
#include <a1/core/config.hpp>
#include <a1/core/myini.hpp>

#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/log.hpp>

namespace a1ctl {
    namespace _ {
        template <typename T>
        inline void update_config_impl(const std::string& key_name, const T& value) {
            a1::config::jb_path g_jb;
            a1::ini::ini_parser pini;
            std::string config_file = g_jb.a1config + "/config.ini";
            if (!xmz::aux::is_dir(g_jb.a1_dir))  xmz::fs::mkdir(g_jb.a1_dir);
            if (!xmz::aux::is_file(config_file)) a1_conf();
            pini.parse_file(config_file);
            if constexpr (std::is_same_v<T, bool>)     pini.set("", key_name, value ? "true" : "false");
            else if constexpr (std::is_same_v<T, int>) pini.set_int("", key_name, value);
            else static_assert(sizeof(T) == 0, "unsupported config value type");
            pini.save_cover(config_file);
            xmz::log::info("the configuration has been updated:", key_name, "=", value);
        }
    } /* namespace _ */
    inline void update_config(const std::string& key_name, bool value = false) { _::update_config_impl(key_name, value); }
    inline void update_config_int(const std::string& key_name, int value) { _::update_config_impl(key_name, value); }
} /* namespace a1ctl */
