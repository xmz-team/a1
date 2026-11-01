// main.cc
#include <src/bin/ui/uialert.hpp>
#include <cstdio>

int main() {
    auto r1 = a1::bin::uialert::body("Title", "Hello world", "OK", "Cancel");
    std::printf("button=%lu\n", r1.button);
    auto r2 = a1::bin::uialert::input("Login", "Username");
    for (auto &s : r2.inputs)
        std::printf("input=%s\n", s.c_str());
    auto r3 = a1::bin::uialert::secure("Password", "Enter password");
    for (auto &s : r3.inputs)
        std::printf("secure=%s\n", s.c_str());
    auto r4 = a1::bin::uialert::timeout("Timeout", 10.0, "", "OK", "", "",
                                   kCFUserNotificationCautionAlertLevel);
    std::printf("timeout button=%lu\n", r4.button);
    return 0;
}
