// traits.hpp
#pragma once
extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}
#include <string>
#include <vector>
#include <map>
#include <type_traits>
#include <a1/core/mod/a1mod_struct.hpp>

namespace a1mod::lua_traits {
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
    template<> struct to_lua<std::map<std::string, std::string>> {
        static void push(lua_State* L, const std::map<std::string, std::string>& map) {
            lua_newtable(L);
            for (const auto& pair : map) {
                lua_pushlstring(L, pair.first.c_str(), pair.first.size());
                lua_pushlstring(L, pair.second.c_str(), pair.second.size());
                lua_settable(L, -3);
            }
        }
    };
    template<> struct to_lua<std::map<std::string, double>> {
        static void push(lua_State* L, const std::map<std::string, double>& map) {
            lua_newtable(L);
            for (const auto& pair : map) {
                lua_pushlstring(L, pair.first.c_str(), pair.first.size());
                lua_pushnumber(L, pair.second);
                lua_settable(L, -3);
            }
        }
    };

    template<> struct to_lua<a1::_modapi::vm_swap_usage_info> {
        static void push(lua_State* L, const a1::_modapi::vm_swap_usage_info& v) {
            lua_newtable(L);
            lua_pushboolean(L, v.ok);            lua_setfield(L, -2, "ok");
            lua_pushinteger(L, (lua_Integer)v.total);  lua_setfield(L, -2, "total");
            lua_pushinteger(L, (lua_Integer)v.used);   lua_setfield(L, -2, "used");
            lua_pushinteger(L, (lua_Integer)v.avail);  lua_setfield(L, -2, "avail");
            lua_pushinteger(L, (lua_Integer)v.free);   lua_setfield(L, -2, "free");
            lua_pushnumber (L, v.used_ratio);          lua_setfield(L, -2, "used_ratio");
            if (!v.ok) {
                lua_pushstring (L, v.error.c_str());   lua_setfield(L, -2, "error");
                lua_pushinteger(L, v.err_code);        lua_setfield(L, -2, "err_code");
            }
        }
    };
} /* namespace a1mod::lua_traits */
