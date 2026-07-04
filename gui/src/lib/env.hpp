/*
 * env.hpp
 * Created by XMZ <ad-ios334@outlook.com> on 10/3/26
 * Copyright (c) 2025-2026 XMZ <ad-ios334@outlook.com> All rights reserved.
 */

#ifndef A1_GUI_ENV_HPP
#define A1_GUI_ENV_HPP

#include <string>
#include <libxmz/runsh.hpp>

#if defined(__roothide__) || defined(__ios_rh__)
    #include <roothide/roothide.h>
#endif

std::string get_jbarch() {
    #if defined(__rootless__) || defined(__ios_rl__)
        return "iphoneos-arm64";
    #elif defined(__roothide__) || defined(__ios_rh__)
        return "iphoneos-arm64e";
    #else
        return xmz::cmd::runbash("[ -f '/etc/profile' ] && source /etc/profile || { [ -f '/var/jb/etc/profile' ] && source /var/jb/etc/profile || echo 'Where the fuck `profile`?' 1>&2; } && dpkg --print-architecture | tr -d '\n' || echo 'unknown'", xmz::cmd::ShellType::BASH);
    #endif
}

std::string get_jb_path() {
    #if defined(__roothide__) || defined(__ios_rh__)
        return jbroot("/");
    #elif defined(__rootless__) || defined(__ios_rl__)
        return "/var/jb/";
    #else
        std::string arch = get_jbarch();
        if (arch == "iphoneos-arm64") {
            return "/var/jb/";
        } 
        else if (arch == "iphoneos-arm64e") {
            return jbroot("/");
        } 
        else {
            return "/";
        }
    #endif
}

std::string get_a1_path() {
    return get_jb_path() + "a1";
}

#endif // A1_GUI_ENV_HPP
