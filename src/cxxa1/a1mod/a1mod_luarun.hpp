// a1mod_luarun.hop
#pragma once
#include <lua/lua.h>
#include <sol/sol.hpp>

#include <a1/core/a1modcore_api.hpp>

#include <libxmz/io.hpp>
#include <libxmz/log.hpp>

namespace a1mod {
    class luatime {
    public:
        void init() {
            lua.open_libraries(
                sol::lib::base,
                sol::lib::string,
                sol::lib::table,
                sol::lib::math,
                sol::lib::io,
                sol::lib::os,
                sol::lib::package,
                sol::lib::coroutine
            );
        lua["a1"] = a1api;
            lua["a1"] = a1api;
        }
        void run_script(const std::string& script) {
            try {
                lua.script(script);
            } catch (const sol::error& e) {
                xmz::log::error("Lua:", e.what());
            }
        }
        void run_file(const std::string& filename) { lua.script_file(filename); }
        sol::state& get_state() { return lua; }
    private:
        sol::state lua;
        a1mod::apis::a1api a1api;
    };
} /* a1mod */
