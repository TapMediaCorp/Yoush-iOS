//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
extension SignalApp {
    func warmAvailableEmojiCache() {
        DispatchQueue.global(qos: .background).async {
            Emoji.warmAvailableCache()
        }
    }
    
    func showMainTabBar() {
        let tabbarVC = FLTabbarViewController()
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let rootNav = OWSNavigationController(rootViewController: tabbarVC)
        rootNav.isNavigationBarHidden = true
        appDelegate.window?.rootViewController = rootNav
        appDelegate.window?.makeKeyAndVisible()
//        Config Jitsi Callkit Manager
//        CALLKIT_MANAGER.config()
    }
    
    var mainTab:FLTabbarViewController? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let rootNav = appDelegate.window?.rootViewController as? OWSNavigationController else {
            return nil
        }
        return rootNav.viewControllers.first as? FLTabbarViewController
    }
    
    var rootNav:OWSNavigationController? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let rootNav = appDelegate.window?.rootViewController as? OWSNavigationController else {
            return nil
        }
        return rootNav
    }
    
    var currentTab:OWSNavigationController? {
        guard let tabbar = mainTab,
              let nav = tabbar.selectedViewController as? OWSNavigationController? else {
            return nil
        }
        return nav
    }
    
    var isShowingSplitConversationTab: Bool {
        guard let tabBar = mainTab,
              tabBar.selectedIndex == 1 else {
            return false
        }
        return true
    }
    
    func presentConversationInTab(_ thread: TSThread, action: ConversationViewAction, focusMessageId: String?, animated: Bool = true) {
        let threadViewModel = SSKEnvironment.shared.databaseStorage.uiRead {
            return ThreadViewModel(thread: thread, transaction: $0)
        }
        
        let vc = ConversationViewController(threadViewModel: threadViewModel, action: action, focusMessageId: focusMessageId)
        
//        let nav = currentTab ?? rootNav
        let nav = rootNav
        var vcs = [UIViewController]()
        if let viewcontroller = nav?.viewControllers  {
            vcs.append(viewcontroller[0])
            for vc in viewcontroller {
                if vc != vcs[0] {
                    vc.presentingViewController?.dismiss(animated: false, completion: nil)
                }
            }
            vcs.append(vc)
        }
        nav?.setViewControllers(vcs, animated: animated)
//        nav?.pushViewController(vc, animated: animated)
    }
}
