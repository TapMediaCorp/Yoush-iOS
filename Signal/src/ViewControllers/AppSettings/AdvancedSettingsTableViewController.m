//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "AdvancedSettingsTableViewController.h"
#import "DebugLogger.h"
#import "DomainFrontingCountryViewController.h"
#import "OWSCountryMetadata.h"
#import "Pastelog.h"
#import "Yoush-Swift.h"
#import "TSAccountManager.h"
#import <PromiseKit/AnyPromise.h>
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSPreferences.h>
#import <SignalServiceKit/OWSSignalService.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation AdvancedSettingsTableViewController

#pragma mark - Dependencies

- (id<SSKReachabilityManager>)reachabilityManager
{
    return SSKEnvironment.shared.reachabilityManager;
}

#pragma mark -

- (void)loadView
{
    [super loadView];

    self.title = NSLocalizedString(@"SETTINGS_ADVANCED_TITLE", @"");

    self.useThemeBackgroundColors = YES;

    [self observeNotifications];

    [self updateTableContents];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(socketStateDidChange)
                                                 name:NSNotificationWebSocketStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged)
                                                 name:SSKReachability.owsReachabilityDidChange
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)socketStateDidChange
{
    OWSAssertIsOnMainThread();

    [self updateTableContents];
}

- (void)reachabilityChanged
{
    OWSAssertIsOnMainThread();

    [self updateTableContents];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self updateTableContents];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    __weak AdvancedSettingsTableViewController *weakSelf = self;

    // OWSTableSection *loggingSection = [OWSTableSection new];
    // loggingSection.headerTitle = NSLocalizedString(@"LOGGING_SECTION", nil);
    // [loggingSection addItem:[OWSTableItem switchItemWithText:NSLocalizedString(@"SETTINGS_ADVANCED_DEBUGLOG", @"")
    //                             accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"enable_debug_log")
    //                             isOnBlock:^{
    //                                 return [OWSPreferences isLoggingEnabled];
    //                             }
    //                             isEnabledBlock:^{
    //                                 return YES;
    //                             }
    //                             target:weakSelf
    //                             selector:@selector(didToggleEnableLogSwitch:)]];

    // if ([OWSPreferences isLoggingEnabled]) {
    //     [loggingSection
    //         addItem:[OWSTableItem actionItemWithText:NSLocalizedString(@"SETTINGS_ADVANCED_SUBMIT_DEBUGLOG", @"")
    //                          accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"submit_debug_log")
    //                                      actionBlock:^{
    //                                          OWSLogInfo(@"Submitting debug logs");
    //                                          [DDLog flushLog];
    //                                          [Pastelog submitLogs];
    //                                      }]];
    // }

    // if (SSKDebugFlags.audibleErrorLogging) {
    //     [loggingSection
    //         addItem:[OWSTableItem actionItemWithText:NSLocalizedString(
    //                                                      @"SETTINGS_ADVANCED_VIEW_ERROR_LOG", @"table cell label")
    //                          accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"view_error_log")
    //                                      actionBlock:^{
    //                                          [weakSelf didPressViewErrorLog];
    //                                      }]];
    // }

    // [contents addSection:loggingSection];

    // OWSTableSection *pushNotificationsSection = [OWSTableSection new];
    // pushNotificationsSection.headerTitle
    //     = NSLocalizedString(@"PUSH_REGISTER_TITLE", @"Used in table section header and alert view title contexts");
    // [pushNotificationsSection addItem:[OWSTableItem actionItemWithText:NSLocalizedString(@"REREGISTER_FOR_PUSH", nil)
    //                                            accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(
    //                                                                        self, @"reregister_push_notifications")
    //                                                        actionBlock:^{
    //                                                            [weakSelf syncPushTokens];
    //                                                        }]];
    // [contents addSection:pushNotificationsSection];

    // Censorship circumvention has certain disadvantages so it should only be
    // used if necessary.  Therefore:
    //
    // * We disable this setting if the user has a phone number from a censored region -
    //   censorship circumvention will be auto-activated for this user.
    // * We disable this setting if the user is already connected; they're not being
    //   censored.
    // * We continue to show this setting so long as it is set to allow users to disable
    //   it, for example when they leave a censored region.
    // OWSTableSection *censorshipSection = [OWSTableSection new];
    // censorshipSection.headerTitle = NSLocalizedString(@"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION_HEADER",
    //     @"Table header for the 'censorship circumvention' section.");
    // BOOL isAnySocketOpen = TSSocketManager.shared.socketState == OWSWebSocketStateOpen;
    // if (OWSSignalService.sharedInstance.hasCensoredPhoneNumber) {
    //     if (OWSSignalService.sharedInstance.isCensorshipCircumventionManuallyDisabled) {
    //         censorshipSection.footerTitle
    //             = NSLocalizedString(@"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION_FOOTER_MANUALLY_DISABLED",
    //                 @"Table footer for the 'censorship circumvention' section shown when censorship circumvention has "
    //                 @"been manually disabled.");
    //     } else {
    //         censorshipSection.footerTitle = NSLocalizedString(
    //             @"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION_FOOTER_AUTO_ENABLED",
    //             @"Table footer for the 'censorship circumvention' section shown when censorship circumvention has been "
    //             @"auto-enabled based on local phone number.");
    //     }
    // } else if (isAnySocketOpen) {
    //     censorshipSection.footerTitle
    //         = NSLocalizedString(@"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION_FOOTER_WEBSOCKET_CONNECTED",
    //             @"Table footer for the 'censorship circumvention' section shown when the app is connected to the "
    //             @"Signal service.");
    // } else if (!self.reachabilityManager.isReachable) {
    //     censorshipSection.footerTitle
    //         = NSLocalizedString(@"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION_FOOTER_NO_CONNECTION",
    //             @"Table footer for the 'censorship circumvention' section shown when the app is not connected to the "
    //             @"internet.");
    // } else {
    //     censorshipSection.footerTitle = NSLocalizedString(@"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION_FOOTER",
    //         @"Table footer for the 'censorship circumvention' section when censorship circumvention can be manually "
    //         @"enabled.");
    // }

    // Do enable if :
    //
    // * ...Censorship circumvention is already manually enabled (to allow users to disable it).
    //
    // Otherwise, don't enable if:
    //
    // * ...Censorship circumvention is already enabled based on the local phone number.
    // * ...The websocket is connected, since that demonstrates that no censorship is in effect.
    // * ...The internet is not reachable, since we don't want to let users to activate
    //      censorship circumvention unnecessarily, e.g. if they just don't have a valid
    //      internet connection.
    // OWSTableSwitchBlock isCensorshipCircumventionOnBlock = ^{
    //     return OWSSignalService.sharedInstance.isCensorshipCircumventionActive;
    // };
    // // Close over reachabilityManager to avoid leaking a reference to self.
    // id<SSKReachabilityManager> reachabilityManager = self.reachabilityManager;
    // OWSTableSwitchBlock isManualCensorshipCircumventionOnEnabledBlock = ^{
    //     OWSSignalService *service = OWSSignalService.sharedInstance;
    //     if (service.isCensorshipCircumventionActive) {
    //         return YES;
    //     } else if (service.hasCensoredPhoneNumber && service.isCensorshipCircumventionManuallyDisabled) {
    //         return YES;
    //     } else if (TSSocketManager.shared.socketState == OWSWebSocketStateOpen) {
    //         return NO;
    //     } else {
    //         return reachabilityManager.isReachable;
    //     }
    // };

    // [censorshipSection
    //     addItem:[OWSTableItem switchItemWithText:NSLocalizedString(@"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION",
    //                                                  @"Label for the  'manual censorship circumvention' switch.")
    //                      accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"censorship_circumvention")
    //                                    isOnBlock:isCensorshipCircumventionOnBlock
    //                               isEnabledBlock:isManualCensorshipCircumventionOnEnabledBlock
    //                                       target:weakSelf
    //                                     selector:@selector(didToggleEnableCensorshipCircumventionSwitch:)]];

    // if (OWSSignalService.sharedInstance.isCensorshipCircumventionManuallyActivated) {
    //     OWSCountryMetadata *manualCensorshipCircumventionCountry =
    //         [weakSelf ensureManualCensorshipCircumventionCountry];
    //     OWSAssertDebug(manualCensorshipCircumventionCountry);
    //     NSString *text = [NSString
    //         stringWithFormat:NSLocalizedString(@"SETTINGS_ADVANCED_CENSORSHIP_CIRCUMVENTION_COUNTRY_FORMAT",
    //                              @"Label for the 'manual censorship circumvention' country. Embeds {{the manual "
    //                              @"censorship circumvention country}}."),
    //         manualCensorshipCircumventionCountry.localizedCountryName];
    //     [censorshipSection addItem:[OWSTableItem disclosureItemWithText:text
    //                                                         actionBlock:^{
    //                                                             [weakSelf showDomainFrontingCountryView];
    //                                                         }]];
    // }
    // [contents addSection:censorshipSection];

    if (SSKFeatureFlags.pinsForNewUsers) {
        OWSTableSection *pinsSection = [OWSTableSection new];
        pinsSection.headerTitle
        = NSLocalizedString(@"SETTINGS_ADVANCED_PINS_HEADER", @"Table header for the 'pins' section.");
        [pinsSection addItem:[OWSTableItem disclosureItemWithText:NSLocalizedString(@"SETTINGS_ADVANCED_PIN_SETTINGS",
                                                                                    @"Label for the 'advanced pin settings' button.")
                                          accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"pins")
                                                      actionBlock:^{
            [weakSelf showAdvancedPinSettings];
        }]];
        [contents addSection:pinsSection];
    }
    
    //Add hidden conversation pin section
    OWSTableSection *hiddenConversationPinAction = [OWSTableSection new];
    hiddenConversationPinAction.headerTitle = NSLocalizedString(@"HIDDEN_CONVERSATION_PIN", @"");
    if (CurrentAppContext().hideConversationPinCode.length > 0) {
        OWSTableItem *changeItem = [OWSTableItem disclosureItemWithText:NSLocalizedString(@"CHANGE_HIDDEN_CONVERSATION_PIN",
                                                                                          @"")
                                                accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"change_hidden_pin")
                                                            actionBlock:^{
            [weakSelf showChangeHiddenConversationPIN];
        }];
        [hiddenConversationPinAction addItem:changeItem];
    }
    OWSTableItem *resetItem = [OWSTableItem disclosureItemWithText:NSLocalizedString(@"RESET_HIDDEN_CONVERSATION_PIN",
                                                                                      @"")
                                            accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"change_hidden_pin")
                                                        actionBlock:^{
        [weakSelf showResetHiddenConversationPIN];
    }];
    [hiddenConversationPinAction addItem:resetItem];
    
    [contents addSection:hiddenConversationPinAction];
    
    self.contents = contents;
}

- (void)showDomainFrontingCountryView
{
    DomainFrontingCountryViewController *vc = [DomainFrontingCountryViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (OWSCountryMetadata *)ensureManualCensorshipCircumventionCountry
{
    OWSAssertIsOnMainThread();

    OWSCountryMetadata *countryMetadata = nil;
    NSString *countryCode = OWSSignalService.sharedInstance.manualCensorshipCircumventionCountryCode;
    if (countryCode) {
        countryMetadata = [OWSCountryMetadata countryMetadataForCountryCode:countryCode];
    }

    if (!countryMetadata) {
        countryCode = [PhoneNumber defaultCountryCode];
        if (countryCode) {
            countryMetadata = [OWSCountryMetadata countryMetadataForCountryCode:countryCode];
        }
    }

    if (!countryMetadata) {
        countryCode = @"US";
        countryMetadata = [OWSCountryMetadata countryMetadataForCountryCode:countryCode];
        OWSAssertDebug(countryMetadata);
    }

    if (countryMetadata) {
        // Ensure the "manual censorship circumvention" country state is in sync.
        OWSSignalService.sharedInstance.manualCensorshipCircumventionCountryCode = countryCode;
    }

    return countryMetadata;
}

#pragma mark - Actions

- (void)showAdvancedPinSettings
{
    AdvancedPinSettingsTableViewController *vc = [AdvancedPinSettingsTableViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showChangeHiddenConversationPIN
{
    //Show confirm pin first
    OWSPinSetupConvViewController *confirmPinVC = [OWSPinSetupConvViewController creatingWithPinCode:CurrentAppContext().hideConversationPinCode completionHandler:^(OWSPinSetupConvViewController * pinSetup, NSError * error) {
        if (error == nil) {
            [self.navigationController popToViewController:self animated:false completion:^{
                OWSPinSetupConvViewController *vc = [OWSPinSetupConvViewController creatingWithPinCode:@"" completionHandler:^(OWSPinSetupConvViewController * pinSetup, NSError * error) {
                    [pinSetup.navigationController popToViewController:self animated:true completion:nil];
                    if (error == nil) {
                        [OWSActionSheets showActionSheetWithTitle:NSLocalizedString(@"CHANGE_HIDDEN_CONVERSATION_PIN_SUCCESS", @"")];
                        
                        [SDSDatabaseStorage.shared readWithBlock:^(SDSAnyReadTransaction * _Nonnull trans) {
                            //Save it to SignalApp
                            SDSKeyValueStore *keystore = [[SDSKeyValueStore alloc] initWithCollection:@"PIN_CODE"];
                            CurrentAppContext().hideConversationPinCode = [keystore getString:@"PIN_CODE" transaction:trans];
                        }];
                    }
                }];
                vc.isSetupHiddenConversationPin = true;
                [self.navigationController pushViewController:vc animated:true];
            }];
        }
    }];
    confirmPinVC.isSetupHiddenConversationPin = true;
    [self.navigationController pushViewController:confirmPinVC animated:true];
}

- (void)showResetHiddenConversationPIN
{
    ActionSheetController *actionSheet =
        [[ActionSheetController alloc] initWithTitle:NSLocalizedString(@"CONFIRMATION_TITLE", @"")
                                             message:NSLocalizedString(@"RESET_HIDDEN_CONVERSATION_PIN_CONFIRMATION", @"")];
    [actionSheet addAction:[[ActionSheetAction alloc] initWithTitle:NSLocalizedString(@"RESET_HIDDEN_CONVERSATION_PIN_ACTION", @"")
                                                              style:ActionSheetActionStyleDestructive
                                                            handler:^(ActionSheetAction *action) {
        OWSPinSetupConvViewController *vc = [OWSPinSetupConvViewController creatingWithPinCode:@"" completionHandler:^(OWSPinSetupConvViewController * pinSetup, NSError * error) {
            [pinSetup.navigationController popToViewController:self animated:true completion:nil];
            if (error == nil) {
                [OWSActionSheets showActionSheetWithTitle:NSLocalizedString(@"RESET_HIDDEN_CONVERSATION_PIN_SUCCESS", @"")];
                
                [SDSDatabaseStorage.shared readWithBlock:^(SDSAnyReadTransaction * _Nonnull trans) {
                    //Save it to SignalApp
                    SDSKeyValueStore *keystore = [[SDSKeyValueStore alloc] initWithCollection:@"PIN_CODE"];
                    CurrentAppContext().hideConversationPinCode = [keystore getString:@"PIN_CODE" transaction:trans];
                }];
                [self deleteAllHiddenConversations];
            }
        }];
        vc.isSetupHiddenConversationPin = true;
        [self.navigationController pushViewController:vc animated:true];
    }]];
    [actionSheet addAction:[OWSActionSheets cancelAction]];
    
    [self presentActionSheet:actionSheet];
}

- (void)deleteAllHiddenConversations {
    __block NSArray *hiddenConversations = @[];
    [SDSDatabaseStorage.shared readWithBlock:^(SDSAnyReadTransaction * _Nonnull trans) {
        FullTextSearcher *searcher = FullTextSearcher.shared;
        hiddenConversations = [searcher searchAllHiddenConversationWithTransaction:trans];
    }];
    if (hiddenConversations.count > 0) {
        DatabaseStorageAsyncWrite(SDSDatabaseStorage.shared, ^(SDSAnyWriteTransaction *trans) {
            for (TSThread *thread in hiddenConversations) {
                [thread anyRemoveWithTransaction:trans];
            }
        });
    }
}
- (void)syncPushTokens
{
    OWSSyncPushTokensJob *job =
        [[OWSSyncPushTokensJob alloc] initWithAccountManager:AppEnvironment.shared.accountManager
                                                 preferences:Environment.shared.preferences];
    job.uploadOnlyIfStale = NO;
    [job run]
        .then(^{
            [OWSActionSheets showActionSheetWithTitle:NSLocalizedString(@"PUSH_REGISTER_SUCCESS",
                                                          @"Title of alert shown when push tokens sync job succeeds.")];
        })
        .catch(^(NSError *error) {
            [OWSActionSheets showActionSheetWithTitle:NSLocalizedString(@"REGISTRATION_BODY",
                                                          @"Title of alert shown when push tokens sync job fails.")];
        });
}

- (void)didToggleEnableLogSwitch:(UISwitch *)sender
{
    if (!sender.isOn) {
        OWSLogInfo(@"disabling logging.");
        [[DebugLogger sharedLogger] wipeLogs];
        [[DebugLogger sharedLogger] disableFileLogging];
    } else {
        [[DebugLogger sharedLogger] enableFileLogging];
        OWSLogInfo(@"enabling logging.");
    }

    [OWSPreferences setIsLoggingEnabled:sender.isOn];

    [self updateTableContents];
}

- (void)didToggleEnableCensorshipCircumventionSwitch:(UISwitch *)sender
{
    OWSSignalService *service = OWSSignalService.sharedInstance;
    if (sender.isOn) {
        service.isCensorshipCircumventionManuallyDisabled = NO;
        service.isCensorshipCircumventionManuallyActivated = YES;
    } else {
        service.isCensorshipCircumventionManuallyDisabled = YES;
        service.isCensorshipCircumventionManuallyActivated = NO;
    }

    [self updateTableContents];
}

- (void)didPressViewErrorLog
{
    OWSAssertDebug(SSKDebugFlags.audibleErrorLogging);

    [DDLog flushLog];
    NSURL *errorLogsDir = DebugLogger.sharedLogger.errorLogsDir;
    LogPickerViewController *logPicker = [[LogPickerViewController alloc] initWithLogDirUrl:errorLogsDir];
    [self.navigationController pushViewController:logPicker animated:YES];
}

@end

NS_ASSUME_NONNULL_END
