/*
c++ -fobjc-arc \
    -D__rootless__ \
    -framework UIKit \
    -framework Foundation \
    -framework OpenGLES \
    -framework CoreGraphics \
    -framework QuartzCore \
    a1c.mm \
    -o a1 && ldid -S../../a1c.ens.xml -Hsha1 -Hsha256 -M a1 && chmod 6755 a1
*/

#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <string>
#include <errno.h>
#include <cstdlib>
#include <string>
#import <unistd.h>

#import "sponsor.h"
#include <libxmz/io.hpp>
#include <libxmz/apple-ios-ui.hpp>
#include <libxmz/fs.hpp>
#include <libxmz/runsh.hpp>
#include <libxmz/log.hpp>
#include <libxmz/aux.hpp>

// #define __rootless__

#include "lib/env.hpp"
#include "lib/ui_extensions.h"
#include "lib/core.h"
#include "lib/view.h"

#pragma mark - MainTabBarController & Setup
@interface MainTabBarController : UITabBarController
@property (nonatomic, assign) BOOL hasShownTestAlert;
@end

@implementation MainTabBarController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
    [navAppearance configureWithTransparentBackground];
    navAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    navAppearance.titleTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightBold]};
    [UINavigationBar appearance].standardAppearance = navAppearance;
    [UINavigationBar appearance].scrollEdgeAppearance = navAppearance;
    
    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    [tabAppearance configureWithTransparentBackground];
    tabAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    [UITabBar appearance].standardAppearance = tabAppearance;
    if (@available(iOS 15.0, *)) { [UITabBar appearance].scrollEdgeAppearance = tabAppearance; }
    
    UIViewController *v1 = [[UINavigationController alloc] initWithRootViewController:[[StatusViewController alloc] init]];
    v1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"状态" image:[UIImage systemImageNamed:@"gauge"] tag:0];
    
    UIViewController *v2 = [[UINavigationController alloc] initWithRootViewController:[[ModeViewController alloc] init]];
    v2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"模式" image:[UIImage systemImageNamed:@"switch.2"] tag:1];
    
    UIViewController *v3 = [[UINavigationController alloc] initWithRootViewController:[[PriorityViewController alloc] init]];
    v3.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"策略" image:[UIImage systemImageNamed:@"bolt.shield.fill"] tag:2];
    
    UIViewController *v4 = [[UINavigationController alloc] initWithRootViewController:[[ConfigViewController alloc] init]];
    v4.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"维护" image:[UIImage systemImageNamed:@"hammer.fill"] tag:3];
    
    UIViewController *v5 = [[UINavigationController alloc] initWithRootViewController:[[ModuleViewController alloc] init]];
    v5.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"模块" image:[UIImage systemImageNamed:@"puzzlepiece.extension.fill"] tag:4];

    UIViewController *v6 = [[UINavigationController alloc] initWithRootViewController:[[SponsorViewController alloc] init]];
    v6.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"赞助" image:[UIImage systemImageNamed:@"heart.fill"] tag:5];

    self.viewControllers = @[v1, v2, v3, v4, v5, v6];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.hasShownTestAlert) {
        self.hasShownTestAlert = YES;
        NSString *message = [NSString stringWithFormat:@"越狱环境: %s\n引擎路径: %s", get_jbarch().c_str(), get_a1_path().c_str()];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"A1 Control Engine" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (setuid(0) != 0) {
        xmz::log::err("setuid(0) failed");
				xmz::log::err("starting a1gui requires setting UID permissions!");
        return 1;
    }
    // AD::user::change("root", "wheel");
    std::string a1_path = get_a1_path();
    std::string a1_bak_path = a1_path + "/backup";
    xmz::fs::mkdir(a1_path.c_str());
		if (xmz::aux::is_dir(a1_path.c_str()) == 0) {
				xmz::log::warn("mkdir a1 path (a1_path) failed");
		} else {
				xmz::log::info("mkdir a1 path (a1_path) success or already exists");
		}
    xmz::fs::mkdir(a1_bak_path.c_str());
    if (xmz::aux::is_dir(a1_bak_path.c_str()) == 0) {
				xmz::log::warn("mkdir a1 bak path (a1_bak_path) failed");
		} else {
				xmz::log::info("mkdir a1 bak path (a1_bak_path) success or already exists");
		}
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[MainTabBarController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
				xmz::log::info("a1gui has started!");
				if (setuid(0) != 0) {
						xmz::log::error("starting a1gui requires setting UID permissions!");
						return 1;
				} else {
						return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
				}
		}
}
