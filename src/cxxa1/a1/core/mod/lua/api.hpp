// api.hpp
#pragma once
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}
#include <string>
#include <vector>
#include <map>

#include <a1/core/mod/a1modcore_api.hpp>

namespace a1mod {
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

static int lua_SetKernSysctlByName(lua_State* L) {
    a1mod::apis::a1api api;
    std::string name = lua_traits::from_lua<std::string>::get(L, 1);
    int new_value = (int)luaL_checkinteger(L, 2);
    bool result = api.SetKernSysctlByName(name, new_value);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_GetAndSetKernSysctl(lua_State* L) {
    a1mod::apis::a1api api;
    std::string name = lua_traits::from_lua<std::string>::get(L, 1);
    int new_value = (int)luaL_checkinteger(L, 2);
    std::string display_name = lua_traits::from_lua<std::string>::get(L, 3);
    bool result = api.GetAndSetKernSysctl(name, new_value, display_name);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_SetVmSysctlByName(lua_State* L) {
    a1mod::apis::a1api api;
    std::string name = lua_traits::from_lua<std::string>::get(L, 1);
    int new_value = (int)luaL_checkinteger(L, 2);
    bool result = api.SetVmSysctlByName(name, new_value);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_GetAndSetVmSysctl(lua_State* L) {
    a1mod::apis::a1api api;
    std::string name = lua_traits::from_lua<std::string>::get(L, 1);
    int new_value = (int)luaL_checkinteger(L, 2);
    std::string display_name = lua_traits::from_lua<std::string>::get(L, 3);
    bool result = api.GetAndSetVmSysctl(name, new_value, display_name);
    lua_traits::to_lua<bool>::push(L, result);
    return 1;
}

static int lua_GetVmSwapUsage(lua_State* L) {
    a1mod::apis::a1api api;
    api.GetVmSwapUsage();
    return 0;
}

static int lua_GetVmSwapUsageInfo(lua_State* L) {
    a1mod::apis::a1api api;
    auto result = api.GetVmSwapUsageInfo();
    lua_traits::to_lua<std::map<std::string, std::string>>::push(L, result);
    return 1;
}

#define REGISTER_LUA_FUNCTION(name) \
    lua_pushcfunction(L, lua_##name); \
    lua_setfield(L, -2, #name);
} /* namespace a1mod */
