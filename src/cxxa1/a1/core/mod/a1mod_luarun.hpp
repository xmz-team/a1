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
#include <a1/core/mod/a1modcore_api.hpp>
#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1mod {
namespace lua_traits {
    template<typename T> struct from_lua;
    template<> struct from_lua<int> { 
        static int get(lua_State* L, int index) { return (int)luaL_checkinteger(L, index); } };
    template<> struct from_lua<bool> { static bool get(lua_State* L, int index) { return lua_toboolean(L, index) != 0; } };
    template<> struct from_lua<std::string> {
        static std::string get(lua_State* L, int index) {
            size_t len;
            const char* str = luaL_checklstring(L, index, &len);
            return std::string(str, len);
        }
    };
    template<typename T> struct to_lua;
    template<> struct to_lua<int> { static void push(lua_State* L, int value) { lua_pushinteger(L, value); } };
    template<> struct to_lua<bool> { static void push(lua_State* L, bool value) { lua_pushboolean(L, value); } };
    template<> struct to_lua<std::string> { static void push(lua_State* L, const std::string& value) { lua_pushlstring(L, value.c_str(), value.size()); } };
    template<> struct to_lua<std::vector<std::string>> {
        static void push(lua_State* L, const std::vector<std::string>& vec) {
            lua_newtable(L);
            for (size_t i = 0; i < vec.size(); ++i) {
                lua_pushlstring(L, vec[i].c_str(), vec[i].size());
                lua_rawseti(L, -2, (int)i + 1);
            }
        }
    };
    template<> struct to_lua<std::map<std::string, int>> {
        static void push(lua_State* L, const std::map<std::string, int>& map) {
            lua_newtable(L);
            for (const auto& pair : map) {
                lua_pushlstring(L, pair.first.c_str(), pair.first.size());
                lua_pushinteger(L, pair.second);
                lua_settable(L, -3);
            }
        }
    };
}
template<typename T>
T get_arg(lua_State* L, int index) { return lua_traits::from_lua<typename std::decay<T>::type>::get(L, index); }
template<typename... Args, size_t... Indices>
auto get_args(lua_State* L, std::index_sequence<Indices...>) { return std::make_tuple(get_arg<Args>(L, (int)Indices + 1)...); }

static int lua_GetProcessPid(lua_State* L) {
    a1mod::apis::a1api api;
    std::string name = lua_traits::from_lua<std::string>::get(L, 1);
    int result = api.GetProcessPid(name);
    lua_traits::to_lua<int>::push(L, result);
    return 1;
}

static int lua_GetProcessName(lua_State* L) {
    a1mod::apis::a1api api;
    int pid = (int)luaL_checkinteger(L, 1);
    std::string result = api.GetProcessName(pid);
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetNiceValue(lua_State* L) {
    a1mod::apis::a1api api;
    int pid = (int)luaL_checkinteger(L, 1);
    int result = api.GetNiceValue(pid);
    lua_traits::to_lua<int>::push(L, result);
    return 1;
}

static int lua_GetCPUUsage(lua_State* L) {
    a1mod::apis::a1api api;
    int pid = (int)luaL_checkinteger(L, 1);
    int result = api.GetCPUUsage(pid);
    lua_traits::to_lua<int>::push(L, result);
    return 1;
}

static int lua_GetHighPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetHighPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetLowPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetLowPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetCustomPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetCustomPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetParsedHighList(lua_State* L) {
    a1mod::apis::a1api api;
    auto result = api.GetParsedHighList();
    lua_traits::to_lua<std::vector<std::string>>::push(L, result);
    return 1;
}

static int lua_GetParsedLowList(lua_State* L) {
    a1mod::apis::a1api api;
    auto result = api.GetParsedLowList();
    lua_traits::to_lua<std::vector<std::string>>::push(L, result);
    return 1;
}

static int lua_GetParsedCustomList(lua_State* L) {
    a1mod::apis::a1api api;
    auto result = api.GetParsedCustomList();
    lua_traits::to_lua<std::map<std::string, int>>::push(L, result);
    return 1;
}

static int lua_GetPresetHighPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetPresetHighPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetPresetLowPriorityList(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetPresetLowPriorityList();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_IsDeviceLocked(lua_State* L) {
    a1mod::apis::a1api api;
    bool result = api.IsDeviceLocked();
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_IsA1Running(lua_State* L) {
    a1mod::apis::a1api api;
    bool result = api.IsA1Running();
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_GetA1Dir(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetA1Dir();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_GetA1ConfigDir(lua_State* L) {
    a1mod::apis::a1api api;
    std::string result = api.GetA1ConfigDir();
    lua_traits::to_lua<std::string>::push(L, result);
    return 1;
}

static int lua_SetProcessNiceValue(lua_State* L) {
    a1mod::apis::a1api api;
    pid_t pid = (pid_t)luaL_checkinteger(L, 1);
    int nice_value = (int)luaL_checkinteger(L, 2);
    bool result = api.SetProcessNiceValue(pid, nice_value);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_SetProcessJetsamValue(lua_State* L) {
    a1mod::apis::a1api api;
    pid_t pid = (pid_t)luaL_checkinteger(L, 1);
    int32_t jetsam_value = (int32_t)luaL_checkinteger(L, 2);
    bool result = api.SetProcessJetsamValue(pid, jetsam_value);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_SetProcessPriority(lua_State* L) {
    a1mod::apis::a1api api;
    if (lua_isnumber(L, 1)) {
        int pid = (int)luaL_checkinteger(L, 1);
        int priority = (int)luaL_checkinteger(L, 2);
        bool result = api.SetProcessPriority(pid, priority);
        lua_pushboolean(L, result);
    } else if (lua_isstring(L, 1)) {
        const char* name = lua_tostring(L, 1);
        int priority = (int)luaL_checkinteger(L, 2);
        bool result = api.SetProcessPriority(name, priority);
        lua_pushboolean(L, result);
    } else {
        luaL_error(L, "Invalid argument type for SetProcessPriority");
        return 0;
    }
    return 1;
}

#define REGISTER_LUA_FUNCTION(name) \
    lua_pushcfunction(L, lua_##name); \
    lua_setfield(L, -2, #name);

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
        if (!xmz::aux::is_file(filename.c_str())) {
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
        lua_setglobal(L, "a1");
    }
};
} /* a1mod */
