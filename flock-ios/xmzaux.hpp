/*
 * xmzaux.hpp
 * Created by XMZ <ad-ios334@outlook.com> on 10/3/26
 * Copyright (c) 2025-2026 XMZ <ad-ios334@outlook.com> All rights reserved.
 */

# ifndef XMZ_TEAM_AUX_HPP
# define XMZ_TEAM_AUX_HPP

#include <string>
#include <vector>
#include <filesystem>
#include <fstream>
#include <memory>
#include <iostream>
#include <cstring>

# include <limits.h>

#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>


namespace xmz {
    // aux::exist and is_dir and is_file
    // return 0, it exists
    // return 1, it doesn't exist
    namespace aux {
        int exist(const char *path) {
            struct stat st;
            return (stat(path, &st) != 0); /* 0 if exists, 1 if not exists */
        }

        int is_dir(const char *path) {
            struct stat st;
            if (stat(path, &st) != 0) { return 1; /* doesn't exist or error */ }
            return (S_ISDIR(st.st_mode) ? 0 : 1);  /* 0 if is directory, 1 if not */
        }

        int is_file(const char *path) {
            struct stat st;
            if (stat(path, &st) != 0) { return 1; /* doesn't exist or error */ }
            return (S_ISREG(st.st_mode) ? 0 : 1);  // 0 if is file, 1 if not
        }

        constexpr auto& path_exist = exist;

        std::string resolve_path(const std::string& path) {
            char resolved_path[PATH_MAX];
            if (realpath(path.c_str(), resolved_path) != nullptr) {
                return std::string(resolved_path);
            }
            return path;  // Parsing fails to return to the original path
        }
        constexpr auto& parselink = resolve_path;
    } /* namespace aux */

    namespace auxiliary = aux;
} /* namespace xmz */
#endif /* XMZ_TEAM_AUX_HPP */
