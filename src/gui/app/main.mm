// main.mm
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <unistd.h>

#import <ui/ViewControllers/MainTabBarController.h>
#import <core/A1Executor.h>
#include <a1/core/config.hpp>
#import "AppDelegate.h"
#include <core/env.h>
#include <core/cfg.h>

#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/crash.hpp>

int main(int argc, char * argv[]) {
    g_env.init();
    xmz::crash::init_crash_handler(g_jb.a1_dir + "/a1gui_crash.log");
    @autoreleasepool {
        if (setuid(0) != 0 && getuid() != 0) {
            xmz::log::error("a1gui requires root permissions!");
            return 1;
        }
        xmz::log::info("a1gui starting...");
        xmz::log::debug("app path:", g_env.get_self_path());
        xmz::log::debug("uid:", getuid());
        xmz::log::debug("jb path:", g_jb.jb);
        xmz::log::debug("a1 path:", g_jb.a1_dir);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
