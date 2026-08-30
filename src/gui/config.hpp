// config.hpp
#include <string>
#include <libxmz/aux.hpp>

namespace a1gui {
class {
public:
std::string jbroot(const std::string& path) {
    static void *handle = []() -> void* {
        void *h = dlopen("@loader_path/.jbroot/usr/lib/libroothide.dylib", RTLD_LAZY);
        if (!h) {
            xmz::log::error("dlopen error:", dlerror());
        }
        return h;
    }();
    static const char* (*jbroot_func)(const char*) = []() -> decltype(jbroot_func) {
        if (!handle) return nullptr;
        dlerror();
        auto func = (const char* (*)(const char*)) dlsym(handle, "jbroot");
        if (dlerror() != nullptr) {
            xmz::log::error("dlsym error:", dlerror());
            return nullptr;
        }
        return func;
    }();
    if (!handle || !jbroot_func) { return ""; }
    const char *result = jbroot_func(path.c_str());
    return result ? std::string(result) : "";
}

std::string get_jb_type() {
    if (xmz::aux::is_file("/var/jb/a1/.type_is_rootless") == 0) {
        return "iphoneos-arm64";
    } else if (xmz::aux::is_file("/a1/.type_is_roothide") == 0) {
        return "iphoneos-arm64e";
    } else if (xmz::aux::is_file("/var/a1/.type_is_rootful") == 0) {
        return "iphoneos-arm";
    } else {
        return "";
    }
}
std::string get_a1_path() {
    if (get_jb_type() != "" && get_jb_type() == "iphoneos-arm64") {
        return "/var/jb/a1";
    } else if (get_jb_type() != "" && get_jb_type() == "iphoneos-arm64e") {
        return jbroot() + "/a1";
    } else if (get_jb_type() != "" && get_jb_type() == "iphoneos-arm") {
        return "/var/a1";
    } else {
        return "";
    }
}


