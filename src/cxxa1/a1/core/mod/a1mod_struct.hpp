// a1mod_struct.hpp
#pragma once
#include <variant>
#include <cstdint>
namespace a1::_modapi {
struct vm_swap_usage_info {
    bool ok = false;
    int64_t total = 0;
    int64_t used = 0;
    int64_t avail = 0;
    int64_t free = 0;
    double used_ratio = 0.0;
    std::string error;
    int err_code = 0;
};
} /* namespace a1::_modapi */
