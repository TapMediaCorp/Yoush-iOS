//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

@objc
class FLTabbarViewController: UITabBarController {
    
    var databaseStorage: SDSDatabaseStorage { .shared }
    var deviceTransferService: DeviceTransferService { .shared }

    // MARK: -

    fileprivate var deviceTransferNavController: DeviceTransferNavigationController?
    var conversationListVC: ConversationListViewController {
        guard let vcs = viewControllers,
              vcs.count > 0,
              let selectedTab = viewControllers?[0] as? UINavigationController,
              let vc = selectedTab.viewControllers.first as? ConversationListViewController else {
            return ConversationListViewController()
        }
        return vc
    }
    
    @objc var topViewController: UIViewController? {
        return SignalApp.shared().currentTab?.viewControllers.last
//        guard !isCollapsed else {
//            return primaryNavController.topViewController
//        }
//
//        return detailNavController.topViewController ?? primaryNavController.topViewController
    }
//    private lazy var primaryNavController = OWSNavigationController(rootViewController: conversationListVC)
//    private lazy var detailNavController = OWSNavigationController()
    
//    private lazy var primaryNavController = OWSNavigationController(rootViewController: conversationListVC)
//    private lazy var detailNavController = OWSNavigationController()
//    private lazy var lastActiveInterfaceOrientation = CurrentAppContext().interfaceOrientation

    @objc
        public let keyValueStore = SDSKeyValueStore(collection: "PIN_CODE")
    
    @objc
    public let threadIndexStore = SDSKeyValueStore(collection: "THREAD_INDEX")
    
    @objc private(set) weak var selectedConversationViewController: ConversationViewController?

    /// The thread, if any, that is currently presented in the view hieararchy. It may be currently
    /// covered by a modal presentation or a pushed view controller.
    @objc var selectedThread: TSThread? {
        guard let selectedConversationViewController = selectedConversationViewController else { return nil }

        // In order to not show selected when collapsed during an interactive dismissal,
        // we verify the conversation is still in the nav stack when collapsed. There is
        // no interactive dismissal when expanded, so we don't have to do any special check.
        guard let existed = navigationController?.viewControllers.contains(selectedConversationViewController),
              existed == true else {
            return nil
        }
        
        return selectedConversationViewController.thread
    }

    /// Returns the currently selected thread if it is visible on screen, otherwise
    /// returns nil.
    @objc var visibleThread: TSThread? {
        guard view.window?.isKeyWindow == true else { return nil }
        guard selectedConversationViewController?.isViewVisible == true else { return nil }
        return selectedThread
    }

//    @objc var topViewController: UIViewController? {
//        guard !isCollapsed else {
//            return primaryNavController.topViewController
//        }
//
//        return detailNavController.topViewController ?? primaryNavController.topViewController
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: .ThemeDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: UIDevice.current
        )
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: .OWSApplicationDidBecomeActive, object: nil)
        StickerManager.refreshContents()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        
        deviceTransferService.addObserver(self)
        deviceTransferService.startListeningForNewDevices()
        DATABASE_STORE.read { trans in
            let code = self.keyValueStore.getString("PIN_CODE", transaction: trans)
            CurrentAppContext().hideConversationPinCode = code
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        deviceTransferService.removeObserver(self)
        deviceTransferService.stopListeningForNewDevices()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.isDarkThemeEnabled ? .lightContent : .default
    }

    @objc func applyTheme() {
        view.backgroundColor = Theme.secondaryBackgroundColor
//        applyNavBarStyle(collapsed: isCollapsed)
    }

    @objc func orientationDidChange() {
        AssertIsOnMainThread()
        guard UIApplication.shared.applicationState == .active else { return }
//        lastActiveInterfaceOrientation = CurrentAppContext().interfaceOrientation
    }

    @objc func didBecomeActive() {
        AssertIsOnMainThread()
//        lastActiveInterfaceOrientation = CurrentAppContext().interfaceOrientation
    }

    func applyNavBarStyle() {
        guard let owsNavBar = SignalApp.shared().rootNav?.navigationBar as? OWSNavigationBar else {
            return owsFailDebug("unexpected nav bar")
        }
//        owsNavBar.switchToStyle(.default )
    }
    
    
    @objc(closeSelectedConversationAnimated:)
    func closeSelectedConversation(animated: Bool) {
        guard let selectedConversationViewController = selectedConversationViewController else { return }
        
        if let primaryNavController = primaryNavController {
            if let selectedConversationIndex = primaryNavController.viewControllers.firstIndex(of: selectedConversationViewController) {
                let trimmedViewControllers = Array(primaryNavController.viewControllers[0..<selectedConversationIndex])
                primaryNavController.setViewControllers(trimmedViewControllers, animated: animated)
            }
        }
    }
    
    func presentConversation(threadViewModel: ThreadViewModel, action: ConversationViewAction, focusMessageId: String?, animated: Bool) {
        //Clear search bar and list threads
//        clearSearch()
        
        let detailVC = ConversationViewController(threadViewModel: threadViewModel, action: action, focusMessageId: focusMessageId)
        selectedConversationViewController = detailVC

        if animated {
            showDetailViewController(detailVC, sender: self)
        } else {
            UIView.performWithoutAnimation { showDetailViewController(detailVC, sender: self) }
        }
    }
    
    private weak var currentDetailViewController: UIViewController?
    override func showDetailViewController(_ vc: UIViewController, sender: Any?) {
        guard let viewControllersToDisplay = primaryNavController?.viewControllers,
              viewControllersToDisplay.count > 0 else {
            return
        }
        // If we already have a detail VC displayed, we want to replace it.
        // The normal behavior of `showDetailViewController` pushes on
        // top of it in collapsed mode.
        var vcs = [UIViewController]()
        vcs.append(viewControllersToDisplay[0])
        for vc in viewControllersToDisplay {
            if vc != vcs[0] {
                vc.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        vcs.append(vc)
//        if let currentDetailVC = currentDetailViewController,
//           let detailVCIndex = viewControllersToDisplay.firstIndex(of: currentDetailVC) {
//            viewControllersToDisplay = Array(viewControllersToDisplay[0..<detailVCIndex])
//        }
//        viewControllersToDisplay.append(vc)
        primaryNavController?.setViewControllers(vcs, animated: true)

        // If the detail VC is a nav controller, we want to keep track of
        // the root view controller. We use this to determine the start
        // point of the current detail view when replacing it while
        // collapsed. At that point, this nav controller's view controllers
        // will have been merged into the primary nav controller.
        if let vc = vc as? UINavigationController {
            currentDetailViewController = vc.viewControllers.first
        } else {
            currentDetailViewController = vc
        }
    }
    
    @objc
    func presentThread(_ thread: TSThread, action: ConversationViewAction, searchText searchText: String? = "", focusMessageId: String?, animated: Bool) {
        AssertIsOnMainThread()
        
        guard selectedThread?.uniqueId != thread.uniqueId else {
            // If this thread is already selected, pop to the thread if
            // anything else has been presented above the view.
            guard let selectedConversationVC = selectedConversationViewController else { return }
            primaryNavController?.popToViewController(selectedConversationVC, animated: animated)
            return
        }

        // Update the last viewed thread on the conversation list so it
        // can maintain its scroll position when navigating back.
        conversationListVC.lastViewedThread = thread

        let threadViewModel = databaseStorage.uiRead {
            return ThreadViewModel(thread: thread, transaction: $0)
        }
        
        if(threadViewModel.threadRecord.isHided == true) {
            self.databaseStorage.write { transaction in
                let pinCode = self.keyValueStore.getString("PIN_CODE", transaction: transaction)
                
                if(pinCode == searchText) {
                    self.presentConversation(threadViewModel: threadViewModel, action: action, focusMessageId: focusMessageId, animated: animated)
                } else {
                    let vc = PinSetupConvConfirmViewController.init(mode: .confirming(pinToMatch: pinCode ?? "")) { vc,error in
                        if(error == nil) {
                            self.presentConversation(threadViewModel: threadViewModel, action: action, focusMessageId: focusMessageId, animated: animated)
                        }
                    }
                    
                    if animated {
                        self.showDetailViewController(vc, sender: self)
                    } else {
                        UIView.performWithoutAnimation { self.showDetailViewController(vc, sender: self) }
                    }
                }
            }
            
        } else {
            self.presentConversation(threadViewModel: threadViewModel, action: action, focusMessageId: focusMessageId, animated: animated)
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if let presentedViewController = presentedViewController {
            return presentedViewController.supportedInterfaceOrientations
        } else {
            return super.supportedInterfaceOrientations
        }
    }
    
    var primaryNavController:UINavigationController? {
        return SignalApp.shared().rootNav
    }
    
    let globalKeyCommands = [
        UIKeyCommand(
            input: "n",
            modifierFlags: .command,
            action: #selector(showNewConversationView),
            discoverabilityTitle: NSLocalizedString(
                "KEY_COMMAND_NEW_MESSAGE",
                comment: "A keyboard command to present the new message dialog."
            )
        ),
        UIKeyCommand(
            input: "g",
            modifierFlags: .command,
            action: #selector(showNewGroupView),
            discoverabilityTitle: NSLocalizedString(
                "KEY_COMMAND_NEW_GROUP",
                comment: "A keyboard command to present the new group dialog."
            )
        ),
        UIKeyCommand(
            input: ",",
            modifierFlags: .command,
            action: #selector(showAppSettings),
            discoverabilityTitle: NSLocalizedString(
                "KEY_COMMAND_SETTINGS",
                comment: "A keyboard command to present the application settings dialog."
            )
        ),
        UIKeyCommand(
            input: "f",
            modifierFlags: .command,
            action: #selector(focusSearch),
            discoverabilityTitle: NSLocalizedString(
                "KEY_COMMAND_SEARCH",
                comment: "A keyboard command to begin a search on the conversation list."
            )
        ),
        UIKeyCommand(
            input: UIKeyCommand.inputUpArrow,
            modifierFlags: .alternate,
            action: #selector(selectPreviousConversation),
            discoverabilityTitle: NSLocalizedString(
                "KEY_COMMAND_PREVIOUS_CONVERSATION",
                comment: "A keyboard command to jump to the previous conversation in the list."
            )
        ),
        UIKeyCommand(
            input: UIKeyCommand.inputDownArrow,
            modifierFlags: .alternate,
            action: #selector(selectNextConversation),
            discoverabilityTitle: NSLocalizedString(
                "KEY_COMMAND_NEXT_CONVERSATION",
                comment: "A keyboard command to jump to the next conversation in the list."
            )
        )
    ]

    var selectedConversationKeyCommands: [UIKeyCommand] {
        return [
            UIKeyCommand(
                input: "i",
                modifierFlags: [.command, .shift],
                action: #selector(openConversationSettings),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_CONVERSATION_INFO",
                    comment: "A keyboard command to open the current conversation's settings."
                )
            ),
            UIKeyCommand(
                input: "m",
                modifierFlags: [.command, .shift],
                action: #selector(openAllMedia),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_ALL_MEDIA",
                    comment: "A keyboard command to open the current conversation's all media view."
                )
            ),
            UIKeyCommand(
                input: "g",
                modifierFlags: [.command, .shift],
                action: #selector(openGifSearch),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_GIF_SEARCH",
                    comment: "A keyboard command to open the current conversations GIF picker."
                )
            ),
            UIKeyCommand(
                input: "u",
                modifierFlags: .command,
                action: #selector(openAttachmentKeyboard),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_ATTACHMENTS",
                    comment: "A keyboard command to open the current conversation's attachment picker."
                )
            ),
            UIKeyCommand(
                input: "s",
                modifierFlags: [.command, .shift],
                action: #selector(openStickerKeyboard),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_STICKERS",
                    comment: "A keyboard command to open the current conversation's sticker picker."
                )
            ),
            UIKeyCommand(
                input: "a",
                modifierFlags: [.command, .shift],
                action: #selector(archiveSelectedConversation),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_ARCHIVE",
                    comment: "A keyboard command to archive the current coversation."
                )
            ),
            UIKeyCommand(
                input: "u",
                modifierFlags: [.command, .shift],
                action: #selector(unarchiveSelectedConversation),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_UNARCHIVE",
                    comment: "A keyboard command to unarchive the current coversation."
                )
            ),
            UIKeyCommand(
                input: "t",
                modifierFlags: [.command, .shift],
                action: #selector(focusInputToolbar),
                discoverabilityTitle: NSLocalizedString(
                    "KEY_COMMAND_FOCUS_COMPOSER",
                    comment: "A keyboard command to focus the current conversation's input field."
                )
            )
        ]
    }

    override var keyCommands: [UIKeyCommand]? {
        // If there is a modal presented over us, or another window above us, don't respond to keyboard commands.
        guard presentedViewController == nil || view.window?.isKeyWindow != true else { return nil }

        // Don't allow keyboard commands while presenting message actions.
        guard selectedConversationViewController?.isPresentingMessageActions != true else { return nil }

        if selectedThread != nil {
            return selectedConversationKeyCommands + globalKeyCommands
        } else {
            return globalKeyCommands
        }
    }
    
    
}

//MARK: UITabBarControllerDelegate

extension FLTabbarViewController: UITabBarControllerDelegate {
    // UITabBarControllerDelegate method
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        print("Selected \(viewController.title ?? "")")
    }
}

//MARK: Bridge Actions
extension FLTabbarViewController {
    
    @objc func showNewConversationView() {
        conversationListVC.showNewConversationView()
    }

    @objc func showNewGroupView() {
        conversationListVC.showNewGroupView()
    }

    @objc func showAppSettings() {
        conversationListVC.showAppSettings()
    }

    @objc func focusSearch() {
        conversationListVC.focusSearch()
    }
    
    @objc func clearSearch() {
        conversationListVC.clearSearch()
    }

    @objc func selectPreviousConversation() {
        conversationListVC.selectPreviousConversation()
    }

    @objc func selectNextConversation(_ sender: UIKeyCommand) {
        conversationListVC.selectNextConversation()
    }

    @objc func archiveSelectedConversation() {
        conversationListVC.archiveSelectedConversation()
    }

    @objc func unarchiveSelectedConversation() {
        conversationListVC.unarchiveSelectedConversation()
    }
    
    @objc func unhideSelectedConversation(thread: TSThread, completion:@escaping ((Bool) -> (Void))) {
        conversationListVC.unhideSelectedConversation(thread, completion: completion)
    }

    @objc func openConversationSettings() {
        guard let selectedConversationViewController = selectedConversationViewController else {
            return owsFailDebug("unexpectedly missing selected conversation")
        }

        selectedConversationViewController.showConversationSettings()
    }

    @objc func focusInputToolbar() {
        guard let selectedConversationViewController = selectedConversationViewController else {
            return owsFailDebug("unexpectedly missing selected conversation")
        }

        selectedConversationViewController.focusInputToolbar()
    }

    @objc func openAllMedia() {
        guard let selectedConversationViewController = selectedConversationViewController else {
            return owsFailDebug("unexpectedly missing selected conversation")
        }

        selectedConversationViewController.openAllMedia()
    }

    @objc func openStickerKeyboard() {
        guard let selectedConversationViewController = selectedConversationViewController else {
            return owsFailDebug("unexpectedly missing selected conversation")
        }

        selectedConversationViewController.openStickerKeyboard()
    }

    @objc func openAttachmentKeyboard() {
        guard let selectedConversationViewController = selectedConversationViewController else {
            return owsFailDebug("unexpectedly missing selected conversation")
        }

        selectedConversationViewController.openAttachmentKeyboard()
    }

    @objc func openGifSearch() {
        guard let selectedConversationViewController = selectedConversationViewController else {
            return owsFailDebug("unexpectedly missing selected conversation")
        }

        selectedConversationViewController.openGifSearch()
    }
}


import MultipeerConnectivity
extension FLTabbarViewController: DeviceTransferServiceObserver {
    func deviceTransferServiceDiscoveredNewDevice(peerId: MCPeerID, discoveryInfo: [String: String]?) {
        guard deviceTransferNavController?.presentingViewController == nil else { return }
        let navController = DeviceTransferNavigationController()
        deviceTransferNavController = navController
        navController.present(fromViewController: self)
    }

    func deviceTransferServiceDidStartTransfer(progress: Progress) {}

    func deviceTransferServiceDidEndTransfer(error: DeviceTransferService.Error?) {}
}

fileprivate
extension FLTabbarViewController {
    func setupUI() {
        //Assign self for delegate for that ViewController can respond to UITabBarControllerDelegate methods
        self.delegate = self
        
        // Remove default line
        tabBar.shadowImage = UIImage()
        tabBar.backgroundImage = UIImage()
        tabBar.backgroundColor = UIColor.white
        
        // Add only shadow
        tabBar.layer.shadowOffset = CGSize(width: 0, height: 0)
        tabBar.layer.shadowRadius = 8
        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.2
        
        // Add tint color
        UITabBar.appearance().tintColor = Theme.youshGoldColor
        
        let homeVC = HomeViewController()
        let homeNav = OWSNavigationController(rootViewController: homeVC)
        let tabOneBarItem = UITabBarItem(title: "", image: UIImage(named: "24-icon-home"), selectedImage: UIImage(named: "24-icon-home"))
        homeNav.tabBarItem = tabOneBarItem
        
        let messageVC = ConversationListViewController()
//        messageVC.title = NSLocalizedString("HOME_VIEW_TITLE_INBOX", comment: "Title for the conversation list's default mode.")
        let tabTwoBarItem2 = UITabBarItem(title: "", image: UIImage(named: "25-icon-chat"), selectedImage: UIImage(named: "25-icon-chat"))
        messageVC.tabBarItem = tabTwoBarItem2
        let messageNav = OWSNavigationController(rootViewController: messageVC)
        //set conversationSplitViewController for SignalApp
        
        let friendVC = NewFriendsViewController()
//        friendVC.title = "Contacts"
        let friendNav = OWSNavigationController(rootViewController: friendVC)
        let tabThreeBarItem = UITabBarItem(title: "", image: UIImage(named: "26-icon-friends"), selectedImage: UIImage(named: "26-icon-friends"))
        friendNav.tabBarItem = tabThreeBarItem
        
        let setttingsNav = AppSettingsViewController.inModalNavigationController()
//        setttingsNav.title = "Settings"
        let settingBarItem = UITabBarItem(title: "", image: UIImage(named: "ic-user-26"), selectedImage: UIImage(named: "ic-user-26"))
        setttingsNav.tabBarItem = settingBarItem
//        OWSNavigationController *navigationController = [AppSettingsViewController inModalNavigationController];
        
//        let notificationVC = NotificationViewController()
//        let notificationNav = OWSNavigationController(rootViewController: notificationVC)
//        let tabFourBarItem = UITabBarItem(title: "", image: UIImage(named: "27-icon-noti"), selectedImage: UIImage(named: "27-icon-noti"))
//        notificationNav.tabBarItem = tabFourBarItem
//        
//        let showMoreVC = ShowMoresViewController()
//        let showMoresNav = OWSNavigationController(rootViewController: showMoreVC)
//        let tabFiveBarItem = UITabBarItem(title: "", image: UIImage(named: "28-icon-3-dots"), selectedImage: UIImage(named: "28-icon-3-dots"))
//        showMoresNav.tabBarItem = tabFiveBarItem
        
//        viewControllers = [homeNav, messageNav, friendNav, notificationNav, showMoresNav]
        viewControllers = [messageNav, friendNav, setttingsNav]
        
        SignalApp.shared().mainTabBarVC = self
    }
}
