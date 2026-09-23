// MainTabBarController.mm
#import "MainTabBarController.h"
#import "StatusViewController.h"
#import "ModeViewController.h"
#import "PriorityViewController.h"
#import "ConfigViewController.h"
#import "ModuleViewController.h"
#import "SponsorViewController.h"
#include <core/cfg.h>

@implementation MainTabBarController
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupAppearance];
    [self setupViewControllers];
}

- (void)setupAppearance {
    UINavigationBarAppearance *navAppearance = [[UINavigationBarAppearance alloc] init];
    [navAppearance configureWithTransparentBackground];
    navAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    navAppearance.titleTextAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightBold]
    };
    [UINavigationBar appearance].standardAppearance = navAppearance;
    [UINavigationBar appearance].scrollEdgeAppearance = navAppearance;
    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    [tabAppearance configureWithTransparentBackground];
    tabAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    [UITabBar appearance].standardAppearance = tabAppearance;
    if (@available(iOS 15.0, *)) { [UITabBar appearance].scrollEdgeAppearance = tabAppearance; }
}

- (void)setupViewControllers {
    NSArray *items = @[
        @[a1gui::locale("state"), @"gauge", [StatusViewController class]],
        @[a1gui::locale("function"), @"switch.2", [ModeViewController class]],
        @[a1gui::locale("course"), @"bolt.shield.fill", [PriorityViewController class]],
        @[a1gui::locale("config"), @"hammer.fill", [ConfigViewController class]],
        @[a1gui::locale("module_system"), @"puzzlepiece.extension.fill", [ModuleViewController class]],
        @[a1gui::locale("sponsor"), @"heart.fill", [SponsorViewController class]]
    ];
    NSMutableArray *controllers = [NSMutableArray array];
    for (NSArray *item in items) {
        UIViewController *vc = [[item[2] alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:item[0]
                                                       image:[UIImage systemImageNamed:item[1]]
                                                         tag:controllers.count];
        [controllers addObject:nav];
    }
    self.viewControllers = controllers;
}
@end
