// main.mm
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <unistd.h>

#import <gui/ui/ViewControllers/MainTabBarController.h>
#import <gui/core/A1Executor.h>
#include <a1/core/config.hpp>
#import "AppDelegate.h"
#include <gui/core/env.h>
#include <gui/core/cfg.h>
#include <a1/core/a1core.hpp>

#include <libxmz/log.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/aux.hpp>
#include <libxmz/crash.hpp>

int main(int argc, char * argv[]) {
    g_env.init();
    a1::init();
    xmz::crash::init_crash_handler(g_jb.a1_dir + "/a1gui_crash.log");
    int out_fd = open((g_jb.a1_dir + "/a1gui.log").c_str(), O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (out_fd >= 0) {
        dup2(out_fd, STDOUT_FILENO);
        if (out_fd != STDOUT_FILENO) close(out_fd);
    }
    int err_fd = open((g_jb.a1_dir + "/a1guierror.log").c_str(), O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (err_fd >= 0) {
        dup2(err_fd, STDERR_FILENO);
        if (err_fd != STDERR_FILENO) close(err_fd);
    }
    @autoreleasepool {
        xmz::log::info("a1gui starting...");
        xmz::log::debug("app path:", g_env.get_self_path());
        xmz::log::debug("uid:", getuid());
        xmz::log::debug("jb path:", g_jb.jb);
        xmz::log::debug("a1 path:", g_jb.a1_dir);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
