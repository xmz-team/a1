// AppDelegate.mm
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <unistd.h>

#import "AppDelegate.h"
#include <core/cfg.h>
#include <core/env.h>
#import <ui/ViewControllers/MainTabBarController.h>
#import <core/A1Executor.h>
#include <a1/core/config.hpp>

#include <libxmz/log.hpp>

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (setuid(0) != 0 && getuid() != 0) {
        xmz::log::error("a1gui must be started as root!");
        return YES;
    }

    xmz::log::info("a1gui started successfully!");
    xmz::log::info("current uid:", getuid());

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[MainTabBarController alloc] init];
    [self.window makeKeyAndVisible];
    NSString *jb_env = [NSString stringWithUTF8String:g_env.get_jb_env().c_str()];
    NSString *a1_path = [NSString stringWithUTF8String:g_jb.a1_dir.c_str()];
    NSString *a1_app_path = [NSString stringWithUTF8String:g_env.get_self_path().c_str()];
    NSString *a1_PATH_ENV = [NSString stringWithUTF8String:std::getenv("PATH")];

    NSString *message = [NSString stringWithFormat:@"Jailbreak: %@\nA1 Path: %@\nA1 App Path: %@\nPATH: %@", jb_env, a1_path, a1_app_path, a1_PATH_ENV];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"A1 Control Engine" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Know" style:UIAlertActionStyleCancel handler:nil]];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];

    [A1Executor shared];
    return YES;
}
@end
