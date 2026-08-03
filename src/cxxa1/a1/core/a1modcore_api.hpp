// a1modcore_api.hpp
#pragma once
#include <a1/core/a1core.hpp>
#include <a1/core/a1ctlcore.hpp>
#include <libxmz/io.hpp>
#include <libxmz/fs.hpp>
#include <optional>
#include <vector>
#include <map>

namespace a1::_modapi {
class a1api {
public:
    // Get PID through the process name (-1 means not found)
    int GetProcessPid(const std::string& name) { return a1::bin::bundle_pid(name.c_str()); }
    std::string GetProcessName(int pid) { return a1::get::process_name_by_pid(pid); }
    int GetNiceValue(int pid) { return a1::get::nice_by_pid(pid); }
    int GetCPUUsage(int pid) { return a1::get::cpu_by_pid(pid); }
    std::string GetHighPriorityList() { 
        if (xmz::aux::is_file(g_jb.high_f.c_str()) == 0) {
            return xmz::fs::readfile_str(g_jb.high_f);
        }
        return "";
    }
    std::string GetLowPriorityList() { 
        if (xmz::aux::is_file(g_jb.low_f.c_str()) == 0) {
            return xmz::fs::readfile_str(g_jb.low_f);
        }
        return "";
    }
    std::string GetCustomPriorityList() {
        if (xmz::aux::is_file(g_jb.custom_f.c_str()) == 0) {
            return xmz::fs::readfile_str(g_jb.custom_f);
        }
        return "";
    }
    std::vector<std::string> GetParsedHighList() {
        a1::priority_manager pm;
        pm.read_priority_lists();
        return pm.get_high_list();
    }
    std::vector<std::string> GetParsedLowList() {
        a1::priority_manager pm;
        pm.read_priority_lists();
        return pm.get_low_list();
    }
    std::map<std::string, int> GetParsedCustomList() {
        a1::priority_manager pm;
        pm.read_priority_lists();
        return pm.get_custom_list();
    }
    std::string GetPresetHighPriorityList() { return a1::get_sys_high_list_str(); }
    std::string GetPresetLowPriorityList() { return a1::get_sys_low_list_str(); }
    bool IsDeviceLocked() { return a1::check_lockstate(); }
    bool IsA1Running() { return a1ctl::check_a1_running() == 0; }
    std::string GetA1Dir() { return g_jb.a1_dir; }
    std::string GetA1ConfigDir() { return g_jb.a1config; }
    bool SetProcessNiceValue(pid_t pid, int nice_value) {
        if (nice_value < -20 || nice_value > 19) {
            xmz::log::warn("Nice value must be between -20 and 19");
            return false;
        }
        int priority = nice_value + 20;
        return a1::set::priority_renice(pid, priority);
    }
    bool SetProcessJetsamValue(pid_t pid, int32_t jetsam_value) {
        if (jetsam_value < 0 || jetsam_value > 21) {
            xmz::log::warn("Jetsam priority must be between 0 and 21");
            return false;
        }
        if (kill(pid, 0) != 0) {
            xmz::log::error("Process", pid, "does not exist");
            return false;
        }
        return a1::set::priority_jetsamctl(pid, jetsam_value);
    }
    bool SetProcessPriority(int pid, int priority_value) {
        return a1::adjust_process_auto(
            pid, 
            std::to_string(priority_value).c_str()
        ) == 0;
    }
    bool SetProcessPriority(const std::string& process_name, int priority_value) {
        return a1::adjust_process_auto(
            process_name.c_str(),
            std::to_string(priority_value).c_str()
        ) == 0;
    }
private:
    a1::config::jb_path g_jb;
};

} // namespace a1::_modapi

namespace a1mod::apis = a1::_modapi;