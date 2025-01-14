//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "OWSReadTracking.h"
#import "TSInteraction.h"

NS_ASSUME_NONNULL_BEGIN

@class TSContactThread;

typedef NS_ENUM(NSUInteger, RPRecentCallType) {
    RPRecentCallTypeIncoming = 1,
    RPRecentCallTypeOutgoing,
    RPRecentCallTypeIncomingMissed,
    // These call types are used until the call connects.
    RPRecentCallTypeOutgoingIncomplete,
    RPRecentCallTypeIncomingIncomplete,
    RPRecentCallTypeIncomingMissedBecauseOfChangedIdentity,
    RPRecentCallTypeIncomingDeclined,
    RPRecentCallTypeOutgoingMissed,
    RPRecentCallTypeIncomingAnsweredElsewhere,
    RPRecentCallTypeIncomingDeclinedElsewhere,
    RPRecentCallTypeIncomingBusyElsewhere
};

NSString *NSStringFromCallType(RPRecentCallType callType);

@interface TSCall : TSInteraction <OWSReadTracking, OWSPreviewText>

@property (nonatomic, readonly) RPRecentCallType callType;

- (instancetype)initWithUniqueId:(NSString *)uniqueId
                       timestamp:(uint64_t)timestamp
                          thread:(TSThread *)thread NS_UNAVAILABLE;
- (instancetype)initWithUniqueId:(NSString *)uniqueId
                       timestamp:(uint64_t)timestamp
             receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                          thread:(TSThread *)thread NS_UNAVAILABLE;
- (instancetype)initInteractionWithTimestamp:(uint64_t)timestamp thread:(TSThread *)thread NS_UNAVAILABLE;
- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
           receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                        sortId:(uint64_t)sortId
                     timestamp:(uint64_t)timestamp
                uniqueThreadId:(NSString *)uniqueThreadId NS_UNAVAILABLE;

- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithCallType:(RPRecentCallType)callType
                          thread:(TSThread *)thread
                 sentAtTimestamp:(uint64_t)sentAtTimestamp NS_DESIGNATED_INITIALIZER;

// --- CODE GENERATION MARKER

// This snippet is generated by /Scripts/sds_codegen/sds_generate.py. Do not manually edit it, instead run `sds_codegen.sh`.

// clang-format off

- (instancetype)initWithGrdbId:(int64_t)grdbId
                      uniqueId:(NSString *)uniqueId
             receivedAtTimestamp:(uint64_t)receivedAtTimestamp
                          sortId:(uint64_t)sortId
                       timestamp:(uint64_t)timestamp
                  uniqueThreadId:(NSString *)uniqueThreadId
                        callType:(RPRecentCallType)callType
                            read:(BOOL)read
NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(grdbId:uniqueId:receivedAtTimestamp:sortId:timestamp:uniqueThreadId:callType:read:));

// clang-format on

// --- CODE GENERATION MARKER

- (void)updateCallType:(RPRecentCallType)callType;
- (void)updateCallType:(RPRecentCallType)callType transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
