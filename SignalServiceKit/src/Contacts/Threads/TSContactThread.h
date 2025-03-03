//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "TSThread.h"

NS_ASSUME_NONNULL_BEGIN

@class SignalServiceAddress;

@interface TSContactThread : TSThread

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
         conversationColorName:(ConversationColorName)conversationColorName
                  creationDate:(nullable NSDate *)creationDate
                    isArchived:(BOOL)isArchived
                        isHided:(BOOL)isHided
          lastInteractionRowId:(int64_t)lastInteractionRowId
                  messageDraft:(nullable NSString *)messageDraft
                mutedUntilDate:(nullable NSDate *)mutedUntilDate
         shouldThreadBeVisible:(BOOL)shouldThreadBeVisible NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUniqueId:(NSString *)uniqueId NS_UNAVAILABLE;

- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

// TODO: We might want to make this initializer private once we
//       convert getOrCreateThreadWithContactAddress to take "any" transaction.
- (instancetype)initWithContactAddress:(SignalServiceAddress *)contactAddress NS_DESIGNATED_INITIALIZER;

@property (nonatomic, nullable) NSString *nameAlias;

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
           conversationColorName:(ConversationColorName)conversationColorName
                    creationDate:(nullable NSDate *)creationDate
                      isArchived:(BOOL)isArchived
                         isHided:(BOOL)isHided
                  isMarkedUnread:(BOOL)isMarkedUnread
            lastInteractionRowId:(int64_t)lastInteractionRowId
               lastVisibleSortId:(uint64_t)lastVisibleSortId
lastVisibleSortIdOnScreenPercentage:(double)lastVisibleSortIdOnScreenPercentage
                    messageDraft:(nullable NSString *)messageDraft
                  mutedUntilDate:(nullable NSDate *)mutedUntilDate
           shouldThreadBeVisible:(BOOL)shouldThreadBeVisible
              contactPhoneNumber:(nullable NSString *)contactPhoneNumber
                     contactUUID:(nullable NSString *)contactUUID
              hasDismissedOffers:(BOOL)hasDismissedOffers
                       nameAlias:(nullable NSString *)nameAlias
NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(grdbId:uniqueId:conversationColorName:creationDate:isArchived:isHided:isMarkedUnread:lastInteractionRowId:lastVisibleSortId:lastVisibleSortIdOnScreenPercentage:messageDraft:mutedUntilDate:shouldThreadBeVisible:contactPhoneNumber:contactUUID:hasDismissedOffers:nameAlias:));

// clang-format on

// --- CODE GENERATION MARKER

@property (nonatomic, readonly) SignalServiceAddress *contactAddress;
@property (nonatomic) BOOL hasDismissedOffers;


+ (instancetype)getOrCreateThreadWithContactAddress:(SignalServiceAddress *)contactAddress
    NS_SWIFT_NAME(getOrCreateThread(contactAddress:));

+ (instancetype)getOrCreateThreadWithContactAddress:(SignalServiceAddress *)contactAddress
                                        transaction:(SDSAnyWriteTransaction *)transaction;

// Unlike getOrCreateThreadWithContactAddress, this will _NOT_ create a thread if one does not already exist.
+ (nullable instancetype)getThreadWithContactAddress:(SignalServiceAddress *)contactAddress
                                         transaction:(SDSAnyReadTransaction *)transaction;

+ (nullable SignalServiceAddress *)contactAddressFromThreadId:(NSString *)threadId
                                                  transaction:(SDSAnyReadTransaction *)transaction;

// This is only ever used from migration from a pre-UUID world to a UUID world
+ (nullable NSString *)legacyContactPhoneNumberFromThreadId:(NSString *)threadId;

// This method can be used to get the conversation color for a given
// recipient without using a read/write transaction to create a
// contact thread.
+ (NSString *)conversationColorNameForContactAddress:(SignalServiceAddress *)address
                                         transaction:(SDSAnyReadTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
