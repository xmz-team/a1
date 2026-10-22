// sys.hpp
#pragma once
#include <string>
#include <cstdint>
#include <cerrno>
#include <cstring>
#include <sys/sysctl.h>

#include <libxmz/log.hpp>
#include <libxmz/io.hpp>

namespace a1::sys {
    namespace _ {
        inline bool set_sysctl_by_name(const std::string& name, int new_value) {
            size_t size = sizeof(new_value);
            if (sysctlbyname(name.c_str(), nullptr, nullptr, &new_value, size) == -1) {
                xmz::log::error("Failed to set", name, ":", strerror(errno));
                return false;
            }
            return true;
        }

        inline bool get_sysctl_by_name(const std::string& name, int& out_value) {
            size_t size = sizeof(out_value);
            return sysctlbyname(name.c_str(), &out_value, &size, nullptr, 0) == 0;
        }

        template <typename Setter>
        inline bool get_and_set_sysctl_impl(const std::string& name, int new_value, const std::string& display_name, Setter&& setter) {
            int current_value = 0;
            if (get_sysctl_by_name(name, current_value)) xmz::log::info("Current", display_name, ":", current_value);
            else xmz::log::warn("Cannot read current", display_name);

            if (setter(name, new_value)) {
                xmz::log::info("Successfully set", display_name, "to", new_value);
                return true;
            }
            return false;
        }

        inline bool get_and_set_sysctl(const std::string& name, int new_value, const std::string& display_name) { return get_and_set_sysctl_impl(name, new_value, display_name, set_sysctl_by_name); }

        struct swap_usage_info {
            bool ok = false;          // Whether it has been obtained successfully
            int64_t total = 0;        // Total size (bytes)
            int64_t used = 0;         // Used (bytes)
            int64_t avail = 0;        // Available (bytes)
            int64_t free = 0;         // Idle (bytes)
            std::string error;        // Error message in time of failure
            int err_code = 0;         // errno
            double used_ratio = 0.0;  // Usage rate (0.0 ~ 1.0)
        };

        inline swap_usage_info query_vm_swapusage() {
            swap_usage_info info;
            struct xsw_usage swap_usage;
            size_t swap_len = sizeof(swap_usage);
            if (sysctlbyname("vm.swapusage", &swap_usage, &swap_len, nullptr, 0) == -1) {
                info.ok = false;
                info.err_code = errno;
                info.error = strerror(errno);
                return info;
            }
            info.ok = true;
            info.total = static_cast<int64_t>(swap_usage.xsu_total);
            info.used  = static_cast<int64_t>(swap_usage.xsu_used);
            info.avail = static_cast<int64_t>(swap_usage.xsu_avail);
            info.free  = info.total - info.used;
            if (info.free < 0) info.free = info.avail;
            if (info.total > 0) info.used_ratio = static_cast<double>(info.used) / static_cast<double>(info.total);
            return info;
        }
    } /* namespace _ */
    using _::swap_usage_info;
    inline bool set_kern_sysctl_by_name(const std::string& name, int new_value) { return _::set_sysctl_by_name(name, new_value); }
    inline bool get_and_set_kern_sysctl(const std::string& name, int new_value, const std::string& display_name) { return _::get_and_set_sysctl(name, new_value, display_name); }
    inline bool set_vm_sysctl_by_name(const std::string& name, int new_value) { return _::set_sysctl_by_name(name, new_value); }
    inline bool get_and_set_vm_sysctl(const std::string& name, int new_value, const std::string& display_name) { return _::get_and_set_sysctl(name, new_value, display_name); }

    inline void get_vm_swapusage() {
        struct xsw_usage swap_usage;
        size_t swap_len = sizeof(swap_usage);
        if (sysctlbyname("vm.swapusage", &swap_usage, &swap_len, nullptr, 0) == -1) {
            xmz::log::error("Failed to get vm.swapusage:", strerror(errno));
        } else {
            xmz::println(
                "\nvm.swapusage:",
                "\n  total =", swap_usage.xsu_total,
                "\n  used =", swap_usage.xsu_used,
                "\n  avail =", swap_usage.xsu_avail
            );
        }
    }

    inline swap_usage_info get_vm_swapusage_info() { return _::query_vm_swapusage(); }
} /* namespace a1::sys */
