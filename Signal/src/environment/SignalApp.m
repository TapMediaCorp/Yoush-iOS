//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "SignalApp.h"
#import "AppDelegate.h"
#import "ConversationViewController.h"
#import "Yoush-Swift.h"
#import <SignalCoreKit/Threading.h>
#import <SignalMessaging/DebugLogger.h>
#import <SignalMessaging/Environment.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/TSContactThread.h>
#import <SignalServiceKit/TSGroupThread.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kNSUserDefaults_DidTerminateKey = @"kNSUserDefaults_DidTerminateKey";

@interface SignalApp ()

@property (nonatomic) BOOL hasInitialRootViewController;

@end

#pragma mark -

@implementation SignalApp

+ (instancetype)sharedApp
{
    static SignalApp *sharedApp = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedApp = [[self alloc] initDefault];
    });
    return sharedApp;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    [self handleCrashDetection];

    [self warmAvailableEmojiCache];

    return self;
}

#pragma mark - Crash Detection

- (void)handleCrashDetection
{
    NSUserDefaults *userDefaults = CurrentAppContext().appUserDefaults;
#if TESTABLE_BUILD
    // Ignore "crashes" in DEBUG builds; applicationWillTerminate
    // will rarely be called during development.
#else
    _didLastLaunchNotTerminate = [userDefaults objectForKey:kNSUserDefaults_DidTerminateKey] != nil;
#endif
    // Very soon after every launch, we set this key.
    // We clear this key when the app terminates in
    // an orderly way.  Therefore if the key is still
    // set on any given launch, we know that the last
    // launch crashed.
    //
    // Note that iOS will sometimes kill the app for
    // reasons other than crashing, so there will be
    // some false positives.
    [userDefaults setObject:@(YES) forKey:kNSUserDefaults_DidTerminateKey];

    if (self.didLastLaunchNotTerminate) {
        OWSLogWarn(@"Last launched crashed.");
    }
}

- (void)applicationWillTerminate
{
    OWSLogInfo(@"");
    NSUserDefaults *userDefaults = CurrentAppContext().appUserDefaults;
    [userDefaults removeObjectForKey:kNSUserDefaults_DidTerminateKey];
}

#pragma mark - Dependencies

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

+ (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

- (TSAccountManager *)tsAccountManager
{
    OWSAssertDebug(SSKEnvironment.shared.tsAccountManager);

    return SSKEnvironment.shared.tsAccountManager;
}

- (OWSBackup *)backup
{
    return AppEnvironment.shared.backup;
}

#pragma mark -

- (void)setup {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeCallLoggingPreference:)
                                                 name:OWSPreferencesCallLoggingDidChangeNotification
                                               object:nil];
}

- (BOOL)hasSelectedThread
{
    return self.mainTabBarVC.selectedThread != nil;
}

#pragma mark - View Convenience Methods

- (void)presentConversationForAddress:(SignalServiceAddress *)address animated:(BOOL)isAnimated
{
    [self presentConversationForAddress:address action:ConversationViewActionNone animated:(BOOL)isAnimated];
}

- (void)presentConversationForAddress:(SignalServiceAddress *)address
                               action:(ConversationViewAction)action
                             animated:(BOOL)isAnimated
{
    __block TSThread *thread = nil;
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        thread = [TSContactThread getOrCreateThreadWithContactAddress:address transaction:transaction];
    });
    [self presentConversationForThread:thread action:action animated:(BOOL)isAnimated];
}

- (void)presentConversationForThreadId:(NSString *)threadId animated:(BOOL)isAnimated
{
    OWSAssertDebug(threadId.length > 0);

    __block TSThread *_Nullable thread;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
    }];
    if (thread == nil) {
        OWSFailDebug(@"unable to find thread with id: %@", threadId);
        return;
    }

    [self presentConversationForThread:thread animated:isAnimated];
}

- (void)presentConversationForThread:(TSThread *)thread animated:(BOOL)isAnimated
{
    [self presentConversationForThread:thread action:ConversationViewActionNone animated:isAnimated];
}

- (void)presentConversationForThread:(TSThread *)thread action:(ConversationViewAction)action animated:(BOOL)isAnimated
{
    [self presentConversationForThread:thread action:action searchText:nil focusMessageId:nil animated:isAnimated];
}

- (void)presentConversationForThread:(TSThread *)thread action:(ConversationViewAction)action searchText:(NSString *)searchText animated:(BOOL)isAnimated
{
    [self presentConversationForThread:thread action:action searchText:searchText focusMessageId:nil animated:isAnimated];
}


- (void)presentConversationForThread:(TSThread *)thread
                              action:(ConversationViewAction)action
                          searchText:(NSString *)searchText
                      focusMessageId:(nullable NSString *)focusMessageId
                            animated:(BOOL)isAnimated
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.mainTabBarVC);

    OWSLogInfo(@"");

    if (!thread) {
        OWSFailDebug(@"Can't present nil thread.");
        return;
    }

    DispatchMainThreadSafe(^{
        //If the conversation tab is selected
        if (self.mainTabBarVC.visibleThread) {
            if ([self.mainTabBarVC.visibleThread.uniqueId isEqualToString:thread.uniqueId]) {
                [self.mainTabBarVC.selectedConversationViewController popKeyBoard];
                return;
            }
        }
        
        [self.mainTabBarVC presentThread:thread
                                  action:action
                              searchText:searchText
                          focusMessageId:focusMessageId
                                animated:isAnimated];
        //        if (self.isShowingSplitConversationTab) {
        //        }else {
        //            //Show with root navigation controller
//            [self presentConversationInTab:thread
//                                    action:action
//                            focusMessageId:focusMessageId
//                                  animated:true];//Animated should be true
//        }
    });
}

- (void)presentConversationAndScrollToFirstUnreadMessageForThreadId:(NSString *)threadId animated:(BOOL)isAnimated
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(threadId.length > 0);
    OWSAssertDebug(self.mainTabBarVC);

    OWSLogInfo(@"");

    __block TSThread *_Nullable thread;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        thread = [TSThread anyFetchWithUniqueId:threadId transaction:transaction];
    }];
    if (thread == nil) {
        OWSFailDebug(@"unable to find thread with id: %@", threadId);
        return;
    }

    DispatchMainThreadSafe(^{
        // If there's a presented blocking splash, but the user is trying to open a thread,
        // dismiss it. We'll try again next time they open the app. We don't want to block
        // them from accessing their conversations.
        [ExperienceUpgradeManager dismissSplashWithoutCompletingIfNecessary];

        if (self.mainTabBarVC.visibleThread) {
            if ([self.mainTabBarVC.visibleThread.uniqueId isEqualToString:thread.uniqueId]) {
                [self.mainTabBarVC.selectedConversationViewController
                    scrollToDefaultPositionAnimated:isAnimated];
                return;
            }
        }

        [self.mainTabBarVC presentThread:thread
                                                     action:ConversationViewActionNone
                                                 searchText:@""
                                             focusMessageId:nil
                                                   animated:isAnimated];
    });
}

- (void)didChangeCallLoggingPreference:(NSNotification *)notification
{
    [AppEnvironment.shared.callService createCallUIAdapter];
}

#pragma mark - Methods

+ (void)resetAppData
{
    // This _should_ be wiped out below.
    [self resetAppData:true];
}

+ (void)resetAppData:(BOOL)forceExit {
    OWSLogInfo(@"");
    [DDLog flushLog];

    [self.databaseStorage resetAllStorage];
    [OWSUserProfile resetProfileStorage];
    [Environment.shared.preferences removeAllValues];
    [AppEnvironment.shared.notificationPresenter clearAllNotifications];
    [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem appSharedDataDirectoryPath]];
    [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem appDocumentDirectoryPath]];
    [OWSFileSystem deleteContentsOfDirectory:[OWSFileSystem cachesDirectoryPath]];
    [OWSFileSystem deleteContentsOfDirectory:OWSTemporaryDirectory()];
    [OWSFileSystem deleteContentsOfDirectory:NSTemporaryDirectory()];

    [DebugLogger.sharedLogger wipeLogs];
    if (forceExit) {
        exit(0);
    }
}
- (void)showConversationSplitView
{
    [self showMainTabBar];
//    ConversationSplitViewController *splitViewController = [ConversationSplitViewController new];
//
//    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
//    appDelegate.window.rootViewController = splitViewController;
//
//    self.mainTabBarVC = splitViewController;
}

- (void)showOnboardingView:(OnboardingController *)onboardingController
{
    OnboardingNavigationController *navController =
        [[OnboardingNavigationController alloc] initWithOnboardingController:onboardingController];

#if TESTABLE_BUILD
    AccountManager *accountManager = AppEnvironment.shared.accountManager;
    UITapGestureRecognizer *registerGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:accountManager action:@selector(fakeRegistration)];
    registerGesture.numberOfTapsRequired = 8;
    [navController.view addGestureRecognizer:registerGesture];
#else
    UITapGestureRecognizer *submitLogGesture = [[UITapGestureRecognizer alloc] initWithTarget:[Pastelog class]
                                                                                       action:@selector(submitLogs)];
    submitLogGesture.numberOfTapsRequired = 8;
    [navController.view addGestureRecognizer:submitLogGesture];
#endif

    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    appDelegate.window.rootViewController = navController;

    self.mainTabBarVC = nil;
}

- (void)showBackupRestoreView
{
    BackupRestoreViewController *backupRestoreVC = [BackupRestoreViewController new];
    OWSNavigationController *navController =
        [[OWSNavigationController alloc] initWithRootViewController:backupRestoreVC];

    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    appDelegate.window.rootViewController = navController;

    self.mainTabBarVC = nil;
}

- (void)ensureRootViewController:(NSTimeInterval)launchStartedAt
{
    OWSAssertIsOnMainThread();

    OWSLogInfo(@"ensureRootViewController");

    if (!AppReadiness.isAppReady || self.hasInitialRootViewController) {
        return;
    }
    self.hasInitialRootViewController = YES;

    NSTimeInterval startupDuration = CACurrentMediaTime() - launchStartedAt;
    OWSLogInfo(@"Presenting app %.2f seconds after launch started.", startupDuration);

    OnboardingController *onboarding = [OnboardingController new];
    if (onboarding.isComplete) {
        [onboarding markAsOnboarded];

        if (self.backup.hasPendingRestoreDecision) {
            [self showBackupRestoreView];
        } else {
            [self showConversationSplitView];
        }
    } else {
        [self showOnboardingView:onboarding];
    }

    [AppUpdateNag.sharedInstance showAppUpgradeNagIfNecessary];

    [UIViewController attemptRotationToDeviceOrientation];
}

- (BOOL)receivedVerificationCode:(NSString *)verificationCode
{
    UIViewController *frontmostVC = CurrentAppContext().frontmostViewController;
    if (![frontmostVC isKindOfClass:[OnboardingVerificationViewController class]]) {
        OWSLogWarn(@"Not the verification view controller we expected. Got %@ instead", frontmostVC.class);
        return NO;
    }

    OnboardingVerificationViewController *verificationVC = (OnboardingVerificationViewController *)frontmostVC;
    [verificationVC setVerificationCodeAndTryToVerify:verificationCode];
    return YES;
}

- (void)showNewConversationView
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.mainTabBarVC);

    [self.mainTabBarVC showNewConversationView];
}

@end

NS_ASSUME_NONNULL_END
