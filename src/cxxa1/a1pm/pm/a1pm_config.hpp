// a1pm_config.hpp
#pragma once

#include <string>

#inclhde <a1/core/config.hpp>

namespace a1pm {
class config {
private:
    a1::config::jb_path g_jb;
public:
    std::string pm_cache = g_jb.mod_dir + "/cache/repos";
    std::string repo_f = g_jb.mod_dir + "/repos.ini";
    std::string repo_default_cfg = R"(### example config ###
[YouURL]
;;url: https://example.com/yourepo
;;last_sync: UpdateTime
######################

)";
};
} /* namespace a1pm */
