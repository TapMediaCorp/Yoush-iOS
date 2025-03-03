//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class SDSAnyReadTransaction;
@class SignalServiceAddress;
@class TSThread;
@class Contact;
@interface ContactTableViewCell : UITableViewCell

+ (NSString *)reuseIdentifier;

- (void)configureWithRecipientAddress:(SignalServiceAddress *)address;

- (void)configureWithContact:(Contact *)contact;

- (void)configureWithThread:(TSThread *)thread transaction:(SDSAnyReadTransaction *)transaction;

// This method should be called _before_ the configure... methods.
- (void)setAccessoryMessage:(nullable NSString *)accessoryMessage;

// This method should be called _after_ the configure... methods.
- (void)setAttributedSubtitle:(nullable NSAttributedString *)attributedSubtitle;

- (void)setCustomName:(nullable NSString *)customName;
- (void)setCustomNameAttributed:(nullable NSAttributedString *)customName;

- (void)setCustomAvatar:(nullable UIImage *)customAvatar;

- (void)setUseSmallAvatars;

- (NSAttributedString *)verifiedSubtitle;

- (BOOL)hasAccessoryText;

- (void)ows_setAccessoryView:(UIView *)accessoryView;

- (BOOL)allowUserInteraction;

@end

NS_ASSUME_NONNULL_END
