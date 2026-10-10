// a1mod_luarun.hpp
#pragma once
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}
#include <memory>
#include <string>
#include <vector>
#include <map>
#include <type_traits>

#include <a1/core/mod/lua/traits.hpp>
#include <a1/core/mod/a1modcore_api.hpp>
#include <a1/core/mod/lua/api.hpp>

#include <libxmz/aux.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1mod {
template<typename T>
T get_arg(lua_State* L, int index) { return lua_traits::from_lua<typename std::decay<T>::type>::get(L, index); }
template<typename... Args, size_t... Indices>
auto get_args(lua_State* L, std::index_sequence<Indices...>) { return std::make_tuple(get_arg<Args>(L, (int)Indices + 1)...); }

class luatime {
public:
    luatime() : L(nullptr), initialized(false) {}
    ~luatime() { close(); }
    luatime(const luatime&) = delete;
    luatime& operator=(const luatime&) = delete;
    luatime(luatime&& other) noexcept 
        : L(other.L), initialized(other.initialized) {
        other.L = nullptr;
        other.initialized = false;
    }

    void init() {
        if (initialized) return;
        L = luaL_newstate();
        if (!L) {
            xmz::log::error("Failed to create Lua state");
            return;
        }
        luaL_openlibs(L);
        register_a1api();
        initialized = true;
    }

    void close() {
        if (L) {
            lua_close(L);
            L = nullptr;
            initialized = false;
        }
    }

    bool is_initialized() const { return initialized && L != nullptr; }
    lua_State* get_state() const { return L; }

    bool run_script(const std::string& script) {
        if (!is_initialized()) return false;
        if (luaL_loadstring(L, script.c_str()) != LUA_OK) {
            xmz::log::error("Load failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
            xmz::log::error("Execute failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        return true;
    }

    bool run_file(const std::string& filename) {
        if (!is_initialized()) return false;
        if (!xmz::aux::is_file(filename)) {
            xmz::log::warn("File not found:", filename);
            return false;
        }
        if (luaL_loadfile(L, filename.c_str()) != LUA_OK) {
            xmz::log::error("Load failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
            xmz::log::error("Execute failed:", lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        return true;
    }
private:
    lua_State* L;
    bool initialized;
    void register_a1api() {
        lua_newtable(L);
        REGISTER_LUA_FUNCTION(GetProcessPid);
        REGISTER_LUA_FUNCTION(GetProcessName);
        REGISTER_LUA_FUNCTION(GetNiceValue);
        REGISTER_LUA_FUNCTION(GetCPUUsage);
        REGISTER_LUA_FUNCTION(GetHighPriorityList);
        REGISTER_LUA_FUNCTION(GetLowPriorityList);
        REGISTER_LUA_FUNCTION(GetCustomPriorityList);
        REGISTER_LUA_FUNCTION(GetParsedHighList);
        REGISTER_LUA_FUNCTION(GetParsedLowList);
        REGISTER_LUA_FUNCTION(GetParsedCustomList);
        REGISTER_LUA_FUNCTION(GetPresetHighPriorityList);
        REGISTER_LUA_FUNCTION(GetPresetLowPriorityList);
        REGISTER_LUA_FUNCTION(IsDeviceLocked);
        REGISTER_LUA_FUNCTION(IsA1Running);
        REGISTER_LUA_FUNCTION(GetA1Dir);
        REGISTER_LUA_FUNCTION(GetA1ConfigDir);
        REGISTER_LUA_FUNCTION(SetProcessNiceValue);
        REGISTER_LUA_FUNCTION(SetProcessJetsamValue);
        lua_pushcfunction(L, lua_SetProcessPriority);
        lua_setfield(L, -2, "SetProcessPriority");
        REGISTER_LUA_FUNCTION(SetKernSysctlByName);
        REGISTER_LUA_FUNCTION(GetAndSetKernSysctl);
        REGISTER_LUA_FUNCTION(SetVmSysctlByName);
        REGISTER_LUA_FUNCTION(GetAndSetVmSysctl);
        REGISTER_LUA_FUNCTION(GetVmSwapUsage);
        REGISTER_LUA_FUNCTION(GetVmSwapUsageInfo);
        REGISTER_LUA_FUNCTION(GetA1Version);
        lua_setglobal(L, "a1");
    }
};
} /* a1mod */
