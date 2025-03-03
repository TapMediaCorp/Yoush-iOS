//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "ConversationViewController.h"
@class FLTabbarViewController;

NS_ASSUME_NONNULL_BEGIN

@class OnboardingController;
@class SignalServiceAddress;
@class TSThread;

@interface SignalApp : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedApp;

- (void)setup;

@property (nonatomic, readonly) BOOL hasSelectedThread;
@property (nonatomic, readonly) BOOL didLastLaunchNotTerminate;

@property (nonatomic, nullable, weak) FLTabbarViewController *mainTabBarVC;

#pragma mark - Conversation Presentation

- (void)showNewConversationView;

- (void)presentConversationForAddress:(SignalServiceAddress *)address animated:(BOOL)isAnimated;

- (void)presentConversationForAddress:(SignalServiceAddress *)address
                               action:(ConversationViewAction)action
                             animated:(BOOL)isAnimated;

- (void)presentConversationForThreadId:(NSString *)threadId animated:(BOOL)isAnimated;

- (void)presentConversationForThread:(TSThread *)thread animated:(BOOL)isAnimated;

- (void)presentConversationForThread:(TSThread *)thread action:(ConversationViewAction)action animated:(BOOL)isAnimated;

- (void)presentConversationForThread:(TSThread *)thread action:(ConversationViewAction)action searchText:(NSString *)searchText animated:(BOOL)isAnimated;

- (void)presentConversationForThread:(TSThread *)thread
                              action:(ConversationViewAction)action
                          searchText:(NSString *)searchText
                      focusMessageId:(nullable NSString *)focusMessageId
                            animated:(BOOL)isAnimated;

- (void)presentConversationAndScrollToFirstUnreadMessageForThreadId:(NSString *)threadId animated:(BOOL)isAnimated;

#pragma mark - Methods

+ (void)resetAppData;

+ (void)resetAppData:(BOOL)forceExit;

- (void)showOnboardingView:(OnboardingController *)onboardingController;
- (void)showConversationSplitView;
- (void)ensureRootViewController:(NSTimeInterval)launchStartedAt;
- (BOOL)receivedVerificationCode:(NSString *)verificationCode;
- (void)applicationWillTerminate;

@end

NS_ASSUME_NONNULL_END
