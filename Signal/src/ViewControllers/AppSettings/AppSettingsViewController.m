//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "AppSettingsViewController.h"
#import "AboutTableViewController.h"
#import "AdvancedSettingsTableViewController.h"
#import "DebugUITableViewController.h"
#import "NotificationSettingsViewController.h"
#import "OWSBackup.h"
#import "OWSBackupSettingsViewController.h"
#import "OWSLinkedDevicesTableViewController.h"
#import "OWSNavigationController.h"
#import "PrivacySettingsTableViewController.h"
#import "ProfileViewController.h"
#import "RegistrationUtils.h"
#import "Yoush-Swift.h"
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalMessaging/UIUtil.h>
#import <SignalServiceKit/TSAccountManager.h>
#import <SignalServiceKit/TSSocketManager.h>

@interface AppSettingsViewController ()

@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, nullable) OWSInviteFlow *inviteFlow;

@end

#pragma mark -

@implementation AppSettingsViewController

/**
 * We always present the settings controller modally, from within an OWSNavigationController
 */
+ (OWSNavigationController *)inModalNavigationController
{
    AppSettingsViewController *viewController = [AppSettingsViewController new];
    OWSNavigationController *navController =
        [[OWSNavigationController alloc] initWithRootViewController:viewController];

    return navController;
}

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    _contactsManager = Environment.shared.contactsManager;

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Dependencies

- (TSAccountManager *)tsAccountManager
{
    return TSAccountManager.sharedInstance;
}

#pragma mark - UIViewController

- (void)loadView
{
    self.tableViewStyle = UITableViewStylePlain;
    [super loadView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setHidesBackButton:YES];

    OWSAssertDebug([self.navigationController isKindOfClass:[OWSNavigationController class]]);

//    self.navigationItem.leftBarButtonItem =
//        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
//                                                      target:self
//                                                      action:@selector(dismissWasPressed:)
//                                     accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dismiss")];
    [self updateRightBarButtonForTheme];
    [self observeNotifications];

    self.navigationItem.title = NSLocalizedString(@"SETTINGS_NAV_BAR_TITLE", @"Title for settings activity");

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

    __weak AppSettingsViewController *weakSelf = self;

#ifdef INTERNAL
    OWSTableSection *internalSection = [OWSTableSection new];
    [section addItem:[OWSTableItem softCenterLabelItemWithText:@"Internal Build"]];
    [contents addSection:internalSection];
#endif
    
    float customCellHeight = 45;
    OWSTableSection *section = [OWSTableSection new];
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
        return [weakSelf profileHeaderCell];
    }
                                           customRowHeight:100.f
                                               actionBlock:^{
        [weakSelf showProfile];
    }]];
    
    //TODO: Change ThemeIconSettingsColorPalette
    UITableViewCell*(^bulidCustomCell)(NSString*, ThemeIcon, NSString*) = ^UITableViewCell*(NSString *name, ThemeIcon icon, NSString *identifier) {
        return [OWSTableItem buildDisclosureCellWithName:name
                                                    icon:icon
                                 accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, identifier)];
    };
    
    // [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
    //     return bulidCustomCell(NSLocalizedString(@"SETTINGS_INVITE_TITLE", @"Settings table view cell label"),
    //                            ThemeIconSettingsColorPalette,
    //                            @"invite");
    // } customRowHeight:customCellHeight actionBlock:^
    // {
    //     [weakSelf showInviteFlow];
    // }]];

    // Starting with iOS 13, show an appearance section to allow setting the app theme
    // to match the "system" dark/light mode settings and to adjust the app specific
    // language settings.
    if (@available(iOS 13, *)) {
        [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
            return bulidCustomCell(NSLocalizedString(@"SETTINGS_APPEARANCE_TITLE", @"The title for the appearance settings."),
                                   ThemeIconAppearanceSetting,
                                   @"appearance");
        } customRowHeight:customCellHeight actionBlock:^
        {
            [weakSelf showAppearance];
        }]];
    }

    [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
        return bulidCustomCell(NSLocalizedString(@"SETTINGS_PRIVACY_TITLE", @"Settings table view cell label"),
                               ThemeIconPrivacySetting,
                               @"privacy");
    } customRowHeight:customCellHeight actionBlock:^
    {
        [weakSelf showPrivacy];
    }]];
    
    [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
        return bulidCustomCell(NSLocalizedString(@"SETTINGS_NOTIFICATIONS", nil),
                               ThemeIconNotificationSetting,
                               @"notifications");
    } customRowHeight:customCellHeight actionBlock:^
    {
        [weakSelf showNotifications];
    }]];

    [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
        return bulidCustomCell(NSLocalizedString(@"SETTINGS_ADVANCED_TITLE", @""),
                               ThemeIconAdvancedSetting,
                               @"advanced");
    } customRowHeight:customCellHeight actionBlock:^
    {
        [weakSelf showAdvanced];
    }]];

    [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
        return bulidCustomCell(NSLocalizedString(@"SETTINGS_ABOUT", @""),
                               ThemeIconInfoSetting,
                               @"about");
    } customRowHeight:customCellHeight actionBlock:^
    {
        [weakSelf showAbout];
    }]];

    
//     [section addItem:[OWSTableItem disclosureItemWithText:NSLocalizedString(@"ACCOUNT_SECURITY", nil)
//                                   accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"")
//                                               actionBlock:^{
// //                                                  [weakSelf showNotifications];
//                                               }]];
    
    
//     [section addItem:[OWSTableItem disclosureItemWithText:NSLocalizedString(@"STORY_MEMORY", nil)
//                                   accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"")
//                                               actionBlock:^{
// //                                                  [weakSelf showNotifications];
//                                               }]];


    // There's actually nothing AFAIK preventing linking another linked device from an
    // existing linked device, but maybe it's not something we want to expose until
    // after unifying the other experiences between secondary/primary devices.
   if (self.tsAccountManager.isRegisteredPrimaryDevice) {
       [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
           return bulidCustomCell(NSLocalizedString(@"LINKED_DEVICES_TITLE", @"Menu item and navbar title for the device manager"),
                                  ThemeIconLinkDevicesSetting,
                                  @"linked_devices");
       } customRowHeight:customCellHeight actionBlock:^
       {
           [weakSelf showLinkedDevices];
       }]];
   }
    
    
//    BOOL isBackupEnabled = [OWSBackup.sharedManager isBackupEnabled];
//    BOOL showBackup = (OWSBackup.isFeatureEnabled && isBackupEnabled);
//    if (showBackup) {
//        [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
//            return bulidCustomCell(NSLocalizedString(@"SETTINGS_BACKUP", @"Label for the backup view in app settings."),
//                                   ThemeIconSettingsColorPalette,
//                                   @"backup");
//        } customRowHeight:customCellHeight actionBlock:^
//        {
//            [weakSelf showBackup];
//        }]];
//    }
    

#ifdef USE_DEBUG_UI
//    [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
//        return bulidCustomCell(@"Debug UI",
//                               @"debugui");
//    } customRowHeight:customCellHeight actionBlock:^
//    {
//        [weakSelf showDebugUI];
//    }]];
#endif

    // if (self.tsAccountManager.isDeregistered) {
    //     [section
    //         addItem:[self destructiveButtonItemWithTitle:self.tsAccountManager.isPrimaryDevice
    //                           ? NSLocalizedString(@"SETTINGS_REREGISTER_BUTTON", @"Label for re-registration button.")
    //                           : NSLocalizedString(@"SETTINGS_RELINK_BUTTON", @"Label for re-link button.")
    //                              accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"reregister")
    //                                             selector:@selector(reregisterUser)
    //                                                color:Theme.accentBlueColor]];
    //     [section addItem:[self destructiveButtonItemWithTitle:NSLocalizedString(@"SETTINGS_DELETE_DATA_BUTTON",
    //                                                               @"Label for 'delete data' button.")
    //                                   accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"delete_data")
    //                                                  selector:@selector(deleteUnregisterUserData)
    //                                                     color:UIColor.ows_accentRedColor]];
    // } else if (self.tsAccountManager.isRegisteredPrimaryDevice) {
    //     [section
    //         addItem:[self destructiveButtonItemWithTitle:NSLocalizedString(@"SETTINGS_DELETE_ACCOUNT_BUTTON", @"")
    //                              accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"delete_account")
    //                                             selector:@selector(unregisterUser)
    //                                                color:UIColor.ows_accentRedColor]];
    // } else {
    //     [section addItem:[self destructiveButtonItemWithTitle:NSLocalizedString(@"SETTINGS_DELETE_DATA_BUTTON",
    //                                                               @"Label for 'delete data' button.")
    //                                   accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"delete_data")
    //                                                  selector:@selector(deleteLinkedData)
    //                                                     color:UIColor.ows_accentRedColor]];
    // }

    [contents addSection:section];

    self.contents = contents;
}

- (OWSTableItem *)destructiveButtonItemWithTitle:(NSString *)title
                         accessibilityIdentifier:(NSString *)accessibilityIdentifier
                                        selector:(SEL)selector
                                           color:(UIColor *)color
{
    __weak AppSettingsViewController *weakSelf = self;
   return [OWSTableItem
        itemWithCustomCellBlock:^{
            UITableViewCell *cell = [OWSTableItem newCell];
            cell.preservesSuperviewLayoutMargins = YES;
            cell.contentView.preservesSuperviewLayoutMargins = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            const CGFloat kButtonHeight = 40.f;
            OWSFlatButton *button = [OWSFlatButton buttonWithTitle:title
                                                              font:[OWSFlatButton fontForHeight:kButtonHeight]
                                                        titleColor:[UIColor whiteColor]
                                                   backgroundColor:color
                                                            target:weakSelf
                                                          selector:selector];
            [cell.contentView addSubview:button];
            [button autoSetDimension:ALDimensionHeight toSize:kButtonHeight];
            [button autoVCenterInSuperview];
            [button autoPinLeadingAndTrailingToSuperviewMargin];
            button.accessibilityIdentifier = accessibilityIdentifier;

            return cell;
        }
                customRowHeight:90.f
                    actionBlock:nil];
}

- (UITableViewCell *)profileHeaderCell
{
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UIImage *_Nullable localProfileAvatarImage = [OWSProfileManager.sharedManager localProfileAvatarImage];
    // UIImage *avatarImage = (localProfileAvatarImage
    //         ?: [[[OWSContactAvatarBuilder alloc] initForLocalUserWithDiameter:kMediumAvatarSize] buildDefaultImage]);
     UIImage *avatarImage = (localProfileAvatarImage
            ?: [UIImage imageNamed:@"30-avatar-profile.png"]);
    OWSAssertDebug(avatarImage);

    AvatarImageView *avatarView = [[AvatarImageView alloc] initWithImage:avatarImage];
    [cell.contentView addSubview:avatarView];
    [avatarView autoVCenterInSuperview];
    [avatarView autoPinLeadingToSuperviewMargin];
    [avatarView autoSetDimension:ALDimensionWidth toSize:kMediumAvatarSize];
    [avatarView autoSetDimension:ALDimensionHeight toSize:kMediumAvatarSize];

    if (!localProfileAvatarImage) {
        UIImageView *cameraImageView = [UIImageView new];
        [cameraImageView setTemplateImageName:@"31-icon-camera" tintColor:Theme.grayBorderIconColor];
        [cell.contentView addSubview:cameraImageView];

        [cameraImageView autoSetDimensionsToSize:CGSizeMake(21, 21)];
        cameraImageView.contentMode = UIViewContentModeCenter;
        cameraImageView.backgroundColor = Theme.toastForegroundColor;
        cameraImageView.layer.cornerRadius = 10.5;
        cameraImageView.layer.shadowColor =
            [(Theme.isDarkThemeEnabled ? Theme.darkThemeWashColor : Theme.primaryTextColor) CGColor];
        cameraImageView.layer.shadowOffset = CGSizeMake(1, 1);
        cameraImageView.layer.shadowOpacity = 0.5;
        cameraImageView.layer.shadowRadius = 4;

        [cameraImageView autoPinTrailingToEdgeOfView:avatarView];
        [cameraImageView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:avatarView];
    }

    UIView *nameView = [UIView containerView];
    [cell.contentView addSubview:nameView];
    [nameView autoVCenterInSuperview];
    [nameView autoPinLeadingToTrailingEdgeOfView:avatarView offset:16.f];

    UILabel *titleLabel = [UILabel new];
    NSString *_Nullable localProfileName = [OWSProfileManager.sharedManager localFullName];
    if (localProfileName.length > 0) {
        titleLabel.text = localProfileName;
        titleLabel.textColor = Theme.blueTextColor;
        titleLabel.font = [UIFont ows_dynamicTypeTitle2Font];
    } else {
        titleLabel.text = NSLocalizedString(
            @"APP_SETTINGS_EDIT_PROFILE_NAME_PROMPT", @"Text prompting user to edit their profile name.");
        titleLabel.textColor = Theme.blueTextColor;
        titleLabel.font = [UIFont ows_dynamicTypeHeadlineFont];
    }
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [nameView addSubview:titleLabel];
    [titleLabel autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [titleLabel autoPinWidthToSuperview];

    __block UIView *lastTitleView = titleLabel;
    const CGFloat kSubtitlePointSize = 14.f;
    void (^addSubtitle)(NSString *) = ^(NSString *subtitle) {
        UILabel *subtitleLabel = [UILabel new];
        subtitleLabel.textColor = Theme.primaryTextColor;
        subtitleLabel.font = [UIFont ows_regularFontWithSize:kSubtitlePointSize];
        subtitleLabel.text = subtitle;
        subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [nameView addSubview:subtitleLabel];
        [subtitleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastTitleView];
        [subtitleLabel autoPinLeadingToSuperviewMargin];
        lastTitleView = subtitleLabel;
    };

    addSubtitle(
        [PhoneNumber bestEffortFormatPartialUserSpecifiedTextToLookLikeAPhoneNumber:[TSAccountManager localNumber]]);

    NSString *_Nullable username = [OWSProfileManager.sharedManager localUsername];
    if (username.length > 0) {
        addSubtitle([CommonFormats formatUsername:username]);
    }

    [lastTitleView autoPinEdgeToSuperviewEdge:ALEdgeBottom];

    // UIImage *disclosureImage = [UIImage imageNamed:(CurrentAppContext().isRTL ? @"NavBarBack" : @"NavBarBackRTL")];
    // OWSAssertDebug(disclosureImage);
    // UIImageView *disclosureButton =
    //     [[UIImageView alloc] initWithImage:[disclosureImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    // disclosureButton.tintColor = [UIColor colorWithRGBHex:0xcccccc];
    // [cell.contentView addSubview:disclosureButton];
    // [disclosureButton autoVCenterInSuperview];
    // [disclosureButton autoPinTrailingToSuperviewMargin];
    // [disclosureButton autoPinLeadingToTrailingEdgeOfView:nameView offset:16.f];
    // [disclosureButton setContentCompressionResistancePriority:(UILayoutPriorityDefaultHigh + 1)
    //                                                   forAxis:UILayoutConstraintAxisHorizontal];

    cell.accessibilityIdentifier = ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"profile");

    return cell;
}

- (void)showInviteFlow
{
    OWSInviteFlow *inviteFlow = [[OWSInviteFlow alloc] initWithPresentingViewController:self];
    self.inviteFlow = inviteFlow;
    [inviteFlow presentWithIsAnimated:YES completion:nil];
}

- (void)showPrivacy
{
    PrivacySettingsTableViewController *vc = [[PrivacySettingsTableViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAppearance
{
    AppearanceSettingsTableViewController *vc = [AppearanceSettingsTableViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showNotifications
{
    NotificationSettingsViewController *vc = [[NotificationSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showLinkedDevices
{
    OWSLinkedDevicesTableViewController *vc = [OWSLinkedDevicesTableViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showProfile
{
    ProfileViewController *profileVC =
        [[ProfileViewController alloc] initWithMode:ProfileViewMode_AppSettings
                                  completionHandler:^(ProfileViewController *completedVC) {
                                      [completedVC.navigationController popViewControllerAnimated:YES];
                                  }];
    [self.navigationController pushViewController:profileVC animated:YES];
}

- (void)showAdvanced
{
    AdvancedSettingsTableViewController *vc = [[AdvancedSettingsTableViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showAbout
{
    AboutTableViewController *vc = [[AboutTableViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showBackup
{
    OWSBackupSettingsViewController *vc = [OWSBackupSettingsViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

#ifdef USE_DEBUG_UI
- (void)showDebugUI
{
    [DebugUITableViewController presentDebugUIFromViewController:self];
}
#endif

- (void)dismissWasPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Unregister & Re-register

- (void)unregisterUser
{
    [self showDeleteAccountUI:YES];
}

- (void)deleteLinkedData
{
    ActionSheetController *actionSheet =
        [[ActionSheetController alloc] initWithTitle:NSLocalizedString(@"CONFIRM_DELETE_LINKED_DATA_TITLE", @"")
                                             message:NSLocalizedString(@"CONFIRM_DELETE_LINKED_DATA_TEXT", @"")];
    [actionSheet addAction:[[ActionSheetAction alloc] initWithTitle:NSLocalizedString(@"PROCEED_BUTTON", @"")
                                                              style:ActionSheetActionStyleDestructive
                                                            handler:^(ActionSheetAction *action) {
                                                                [SignalApp resetAppData];
                                                            }]];
    [actionSheet addAction:[OWSActionSheets cancelAction]];

    [self presentActionSheet:actionSheet];
}

- (void)deleteUnregisterUserData
{
    [self showDeleteAccountUI:NO];
}

- (void)showDeleteAccountUI:(BOOL)isRegistered
{
    __weak AppSettingsViewController *weakSelf = self;

    ActionSheetController *actionSheet =
        [[ActionSheetController alloc] initWithTitle:NSLocalizedString(@"CONFIRM_ACCOUNT_DESTRUCTION_TITLE", @"")
                                             message:NSLocalizedString(@"CONFIRM_ACCOUNT_DESTRUCTION_TEXT", @"")];
    [actionSheet addAction:[[ActionSheetAction alloc] initWithTitle:NSLocalizedString(@"PROCEED_BUTTON", @"")
                                                              style:ActionSheetActionStyleDestructive
                                                            handler:^(ActionSheetAction *action) {
                                                                [weakSelf deleteAccount:isRegistered];
                                                            }]];
    [actionSheet addAction:[OWSActionSheets cancelAction]];

    [self presentActionSheet:actionSheet];
}

- (void)deleteAccount:(BOOL)isRegistered
{
    if (isRegistered) {
        [ModalActivityIndicatorViewController
            presentFromViewController:self
                            canCancel:NO
                      backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
                          [TSAccountManager
                              unregisterTextSecureWithSuccess:^{
                                  [SignalApp resetAppData];
                              }
                              failure:^(NSError *error) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      [modalActivityIndicator dismissWithCompletion:^{
                                          [OWSActionSheets
                                              showActionSheetWithTitle:NSLocalizedString(
                                                                           @"UNREGISTER_SIGNAL_FAIL", @"")];
                                      }];
                                  });
                              }];
                      }];
    } else {
        [SignalApp resetAppData];
    }
}

- (void)reregisterUser
{
    [RegistrationUtils showReregistrationUIFromViewController:self];
}

#pragma mark - Dark Theme

- (UIBarButtonItem *)darkThemeBarButton
{
    UIBarButtonItem *barButtonItem;
    if (Theme.isDarkThemeEnabled) {
        barButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ic_dark_theme_on"]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(didPressDisableDarkTheme:)];
    } else {
        barButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ic_dark_theme_off"]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(didPressEnableDarkTheme:)];
    }
    barButtonItem.accessibilityIdentifier = ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dark_theme");
    return barButtonItem;
}

- (void)didPressEnableDarkTheme:(id)sender
{
    [Theme setCurrentTheme:ThemeMode_Dark];
    [self updateRightBarButtonForTheme];
    [self updateTableContents];
}

- (void)didPressDisableDarkTheme:(id)sender
{
    [Theme setCurrentTheme:ThemeMode_Light];
    [self updateRightBarButtonForTheme];
    [self updateTableContents];
}

- (void)updateRightBarButtonForTheme
{
    if (@available(iOS 13, *)) {
        // Don't show the moon button in iOS 13+, theme settings are now in a menu
        return;
    }
    self.navigationItem.rightBarButtonItem = [self darkThemeBarButton];
}

#pragma mark - Notifications

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localProfileDidChange:)
                                                 name:kNSNotificationNameLocalProfileDidChange
                                               object:nil];
}

- (void)localProfileDidChange:(id)notification
{
    OWSAssertIsOnMainThread();

    [self updateTableContents];
}

@end
