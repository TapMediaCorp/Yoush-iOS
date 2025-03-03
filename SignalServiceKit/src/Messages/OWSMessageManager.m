//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageManager.h"
#import "AppContext.h"
#import "AppReadiness.h"
#import "ContactsManagerProtocol.h"
#import "MimeTypeUtil.h"
#import "NSNotificationCenter+OWS.h"
#import "NotificationsProtocol.h"
#import "OWSAttachmentDownloads.h"
#import "OWSBlockingManager.h"
#import "OWSCallMessageHandler.h"
#import "OWSContact.h"
#import "OWSDevice.h"
#import "OWSDevicesService.h"
#import "OWSDisappearingConfigurationUpdateInfoMessage.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSGroupInfoRequestMessage.h"
#import "OWSIdentityManager.h"
#import "OWSIncomingMessageFinder.h"
#import "OWSIncomingSentMessageTranscript.h"
#import "OWSMessageSender.h"
#import "OWSMessageUtils.h"
#import "OWSOutgoingReceiptManager.h"
#import "OWSReadReceiptManager.h"
#import "OWSRecordTranscriptJob.h"
#import "ProfileManagerProtocol.h"
#import "SSKEnvironment.h"
#import "SSKSessionStore.h"
#import "TSAccountManager.h"
#import "TSAttachment.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import "TSContactThread.h"
#import "TSGroupModel.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSNetworkManager.h"
#import "TSOutgoingMessage.h"
#import "TSQuotedMessage.h"
#import <PromiseKit/AnyPromise.h>
#import <SignalCoreKit/Cryptography.h>
#import <SignalCoreKit/NSData+OWS.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalServiceKit/OWSUnknownProtocolVersionMessage.h>
#import <SignalServiceKit/SignalRecipient.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/OWSSignalService.h>
#import <AFNetworking/AFHTTPSessionManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSMessageManager () <UIDatabaseSnapshotDelegate>

// This should only be accessed while synchronized on self.
@property (nonatomic, readonly) NSMutableSet<NSString *> *groupInfoRequestSet;

@end

#pragma mark -

@implementation OWSMessageManager

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

    _groupInfoRequestSet = [NSMutableSet new];

    OWSSingletonAssert();

    return self;
}

#pragma mark - Dependencies

- (id<OWSCallMessageHandler>)callMessageHandler
{
    OWSAssertDebug(SSKEnvironment.shared.callMessageHandler);

    return SSKEnvironment.shared.callMessageHandler;
}

- (id<ContactsManagerProtocol>)contactsManager
{
    OWSAssertDebug(SSKEnvironment.shared.contactsManager);

    return SSKEnvironment.shared.contactsManager;
}

- (MessageSenderJobQueue *)messageSenderJobQueue
{
    return SSKEnvironment.shared.messageSenderJobQueue;
}

- (OWSBlockingManager *)blockingManager
{
    OWSAssertDebug(SSKEnvironment.shared.blockingManager);

    return SSKEnvironment.shared.blockingManager;
}

- (OWSIdentityManager *)identityManager
{
    OWSAssertDebug(SSKEnvironment.shared.identityManager);

    return SSKEnvironment.shared.identityManager;
}

- (TSNetworkManager *)networkManager
{
    OWSAssertDebug(SSKEnvironment.shared.networkManager);

    return SSKEnvironment.shared.networkManager;
}

- (OWSOutgoingReceiptManager *)outgoingReceiptManager
{
    OWSAssertDebug(SSKEnvironment.shared.outgoingReceiptManager);

    return SSKEnvironment.shared.outgoingReceiptManager;
}

- (id<SyncManagerProtocol>)syncManager
{
    OWSAssertDebug(SSKEnvironment.shared.syncManager);

    return SSKEnvironment.shared.syncManager;
}

- (TSAccountManager *)tsAccountManager
{
    OWSAssertDebug(SSKEnvironment.shared.tsAccountManager);

    return SSKEnvironment.shared.tsAccountManager;
}

- (id<ProfileManagerProtocol>)profileManager
{
    return SSKEnvironment.shared.profileManager;
}

- (id<OWSTypingIndicators>)typingIndicators
{
    return SSKEnvironment.shared.typingIndicators;
}

- (OWSAttachmentDownloads *)attachmentDownloads
{
    return SSKEnvironment.shared.attachmentDownloads;
}

- (SDSDatabaseStorage *)databaseStorage
{
    return SDSDatabaseStorage.shared;
}

- (SSKSessionStore *)sessionStore
{
    return SSKEnvironment.shared.sessionStore;
}

- (id<GroupsV2>)groupsV2
{
    return SSKEnvironment.shared.groupsV2;
}

- (EarlyMessageManager *)earlyMessageManager
{
    return SSKEnvironment.shared.earlyMessageManager;
}

- (MessageProcessing *)messageProcessing
{
    return MessageProcessing.shared;
}

#pragma mark -

- (void)startObserving
{
    [self.databaseStorage appendUIDatabaseSnapshotDelegate:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(databaseDidCommitInteractionChange)
                                                 name:UIDatabaseObserver.databaseDidCommitInteractionChangeNotification
                                               object:nil];
}

- (void)databaseDidCommitInteractionChange
{
    OWSAssertIsOnMainThread();
    OWSLogInfo(@"");

    // Only the main app needs to update the badge count.
    // When app is active, this will occur in response to database changes
    // that affect interactions (see below).
    // When app is not active, we should update badge count whenever
    // changes to interactions are committed.
    if (CurrentAppContext().isMainApp && !CurrentAppContext().isMainAppAndActive) {
        [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
    }
}

#pragma mark - UIDatabaseSnapshotDelegate

- (void)uiDatabaseSnapshotWillUpdate
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(AppReadiness.isAppReady);
}

- (void)uiDatabaseSnapshotDidUpdateWithDatabaseChanges:(id<UIDatabaseChanges>)databaseChanges
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(AppReadiness.isAppReady);

    if (!databaseChanges.didUpdateInteractions) {
        return;
    }

    [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
}

- (void)uiDatabaseSnapshotDidUpdateExternally
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(AppReadiness.isAppReady);

    [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
}

- (void)uiDatabaseSnapshotDidReset
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(AppReadiness.isAppReady);

    [OWSMessageUtils.sharedManager updateApplicationBadgeCount];
}

#pragma mark - Blocking

- (BOOL)isEnvelopeSenderBlocked:(SSKProtoEnvelope *)envelope
{
    OWSAssertDebug(envelope);

    return [self.blockingManager isAddressBlocked:envelope.sourceAddress];
}

- (BOOL)isDataMessageBlocked:(SSKProtoDataMessage *)dataMessage envelope:(SSKProtoEnvelope *)envelope
{
    OWSAssertDebug(dataMessage);
    OWSAssertDebug(envelope);

    NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
    if (groupId != nil) {
        return [self.blockingManager isGroupIdBlocked:groupId];
    } else {
        BOOL senderBlocked = [self isEnvelopeSenderBlocked:envelope];

        // If the envelopeSender was blocked, we never should have gotten as far as decrypting the dataMessage.
        OWSAssertDebug(!senderBlocked);

        return senderBlocked;
    }
}

#pragma mark - message handling

- (BOOL)processEnvelope:(SSKProtoEnvelope *)envelope
          plaintextData:(NSData *_Nullable)plaintextData
        wasReceivedByUD:(BOOL)wasReceivedByUD
            transaction:(SDSAnyWriteTransaction *)transaction
{
    @try {
        [self throws_processEnvelope:envelope
                       plaintextData:plaintextData
                     wasReceivedByUD:wasReceivedByUD
                         transaction:transaction];
        return YES;
    } @catch (NSException *exception) {
        OWSFailDebug(@"Received an invalid envelope: %@", exception.debugDescription);
        return NO;
    }
}

- (void)throws_processEnvelope:(SSKProtoEnvelope *)envelope
                 plaintextData:(NSData *_Nullable)plaintextData
               wasReceivedByUD:(BOOL)wasReceivedByUD
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (!self.tsAccountManager.isRegistered) {
        OWSFailDebug(@"Not registered.");
        return;
    }
    if (!CurrentAppContext().shouldProcessIncomingMessages) {
        OWSFail(@"Should not process messages.");
        return;
    }

    OWSLogInfo(@"handling decrypted envelope: %@", [self descriptionForEnvelope:envelope]);

    if (!envelope.hasValidSource) {
        OWSFailDebug(@"incoming envelope has invalid source");
        return;
    }
    if (!envelope.hasSourceDevice || envelope.sourceDevice < 1) {
        OWSFailDebug(@"incoming envelope has invalid source device");
        return;
    }
    if (!envelope.hasType) {
        OWSFailDebug(@"incoming envelope is missing type.");
        return;
    }

    if ([self isEnvelopeSenderBlocked:envelope]) {
        OWSLogInfo(@"incoming envelope sender is blocked.");
        return;
    }

    [self checkForUnknownLinkedDevice:envelope transaction:transaction];

    switch (envelope.unwrappedType) {
        case SSKProtoEnvelopeTypeCiphertext:
        case SSKProtoEnvelopeTypePrekeyBundle:
        case SSKProtoEnvelopeTypeUnidentifiedSender:
            if (!plaintextData) {
                OWSFailDebug(@"missing decrypted data for envelope: %@", [self descriptionForEnvelope:envelope]);
                return;
            }
            [self throws_handleEnvelope:envelope
                          plaintextData:plaintextData
                        wasReceivedByUD:wasReceivedByUD
                            transaction:transaction];
            break;
        case SSKProtoEnvelopeTypeReceipt:
            OWSAssertDebug(!plaintextData);
            [self handleDeliveryReceipt:envelope transaction:transaction];
            break;
            // Other messages are just dismissed for now.
        case SSKProtoEnvelopeTypeKeyExchange:
            OWSLogWarn(@"Received Key Exchange Message, not supported");
            break;
        case SSKProtoEnvelopeTypeUnknown:
            OWSLogWarn(@"Received an unknown message type");
            break;
        default:
            OWSLogWarn(@"Received unhandled envelope type: %d", (int)envelope.unwrappedType);
            break;
    }
}

- (void)handleDeliveryReceipt:(SSKProtoEnvelope *)envelope transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (![SDS fitsInInt64:envelope.timestamp]) {
        OWSFailDebug(@"Invalid timestamp.");
        return;
    }
    // Old-style delivery notices don't include a "delivery timestamp".
    // TODO: do we need to preserve early old-style delivery receipts?
    [self processDeliveryReceiptsFromRecipient:envelope.sourceAddress
                                sentTimestamps:@[
                                    @(envelope.timestamp),
                                ]
                             deliveryTimestamp:nil
                                   transaction:transaction];
}

// deliveryTimestamp is an optional parameter, since legacy
// delivery receipts don't have a "delivery timestamp".  Those
// messages repurpose the "timestamp" field to indicate when the
// corresponding message was originally sent.
- (NSArray<NSNumber *> *)processDeliveryReceiptsFromRecipient:(SignalServiceAddress *)address
                                               sentTimestamps:(NSArray<NSNumber *> *)sentTimestamps
                                            deliveryTimestamp:(NSNumber *_Nullable)deliveryTimestamp
                                                  transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!address.isValid) {
        OWSFailDebug(@"invalid recipient.");
        return @[];
    }
    if (sentTimestamps.count < 1) {
        OWSFailDebug(@"Missing sentTimestamps.");
        return @[];
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return @[];
    }
    if (deliveryTimestamp != nil && ![SDS fitsInInt64WithNSNumber:deliveryTimestamp]) {
        OWSFailDebug(@"Invalid timestamp.");
        return @[];
    }

    NSMutableArray<NSNumber *> *earlyTimestamps = [NSMutableArray new];

    for (NSNumber *nsTimestamp in sentTimestamps) {
        uint64_t timestamp = [nsTimestamp unsignedLongLongValue];
        if (![SDS fitsInInt64:timestamp]) {
            OWSFailDebug(@"Invalid timestamp.");
            continue;
        }

        NSError *error;
        NSArray<TSOutgoingMessage *> *messages = (NSArray<TSOutgoingMessage *> *)[InteractionFinder
            interactionsWithTimestamp:timestamp
                               filter:^(TSInteraction *interaction) {
                                   return [interaction isKindOfClass:[TSOutgoingMessage class]];
                               }
                          transaction:transaction
                                error:&error];
        if (error != nil) {
            OWSFailDebug(@"Error loading interactions: %@", error);
        }

        if (messages.count < 1) {
            OWSLogInfo(@"Missing message for delivery receipt: %llu", timestamp);
            [earlyTimestamps addObject:@(timestamp)];
        } else {
            if (messages.count > 1) {
                OWSLogInfo(@"More than one message (%lu) for delivery receipt: %llu",
                    (unsigned long)messages.count,
                    timestamp);
            }
            for (TSOutgoingMessage *outgoingMessage in messages) {
                [outgoingMessage updateWithDeliveredRecipient:address
                                            deliveryTimestamp:deliveryTimestamp
                                                  transaction:transaction];
            }
        }
    }

    return earlyTimestamps;
}

- (void)throws_handleEnvelope:(SSKProtoEnvelope *)envelope
                plaintextData:(NSData *)plaintextData
              wasReceivedByUD:(BOOL)wasReceivedByUD
                  transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!plaintextData) {
        OWSFailDebug(@"Missing plaintextData.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (envelope.timestamp < 1) {
        OWSFailDebug(@"Invalid timestamp.");
        return;
    }
    if (![SDS fitsInInt64:envelope.timestamp]) {
        OWSFailDebug(@"Invalid timestamp.");
        return;
    }
    if (!envelope.hasValidSource) {
        OWSFailDebug(@"Invalid source.");
        return;
    }
    if (envelope.sourceDevice < 1) {
        OWSFailDebug(@"Invaid source device.");
        return;
    }

    BOOL duplicateEnvelope = [InteractionFinder existsIncomingMessageWithTimestamp:envelope.timestamp
                                                                           address:envelope.sourceAddress
                                                                    sourceDeviceId:envelope.sourceDevice
                                                                       transaction:transaction];

    if (duplicateEnvelope) {
        OWSLogInfo(@"Ignoring previously received envelope from %@ with timestamp: %llu",
            envelopeAddress(envelope),
            envelope.timestamp);
        return;
    }

    if (envelope.content != nil) {
        NSError *error;
        SSKProtoContent *_Nullable contentProto = [SSKProtoContent parseData:plaintextData error:&error];
        if (error || !contentProto) {
            OWSFailDebug(@"could not parse proto: %@", error);
            return;
        }
        OWSLogInfo(@"handling content: <Content: %@>", [self descriptionForContent:contentProto]);

        if (contentProto.syncMessage) {
            [self throws_handleIncomingEnvelope:envelope
                                withSyncMessage:contentProto.syncMessage
                                  plaintextData:plaintextData
                                wasReceivedByUD:wasReceivedByUD
                                    transaction:transaction];

            [[OWSDeviceManager sharedManager] setHasReceivedSyncMessage];
        } else if (contentProto.dataMessage) {
            [self handleIncomingEnvelope:envelope
                         withDataMessage:contentProto.dataMessage
                           plaintextData:plaintextData
                         wasReceivedByUD:wasReceivedByUD
                             transaction:transaction];
        } else if (contentProto.callMessage) {
            [self handleIncomingEnvelope:envelope withCallMessage:contentProto.callMessage transaction:transaction];
        } else if (contentProto.typingMessage) {
            [self handleIncomingEnvelope:envelope withTypingMessage:contentProto.typingMessage transaction:transaction];
        } else if (contentProto.nullMessage) {
            OWSLogInfo(@"Received null message.");
        } else if (contentProto.receiptMessage) {
            [self handleIncomingEnvelope:envelope
                      withReceiptMessage:contentProto.receiptMessage
                             transaction:transaction];
        } else {
            OWSLogWarn(@"Ignoring envelope. Content with no known payload");
        }
    } else if (envelope.legacyMessage != nil) { // DEPRECATED - Remove after all clients have been upgraded.
        NSError *error;
        SSKProtoDataMessage *_Nullable dataMessageProto = [SSKProtoDataMessage parseData:plaintextData error:&error];
        if (error || !dataMessageProto) {
            OWSFailDebug(@"could not parse proto: %@", error);
            return;
        }
        OWSLogInfo(@"handling message: <DataMessage: %@ />", [self descriptionForDataMessage:dataMessageProto]);

        [self handleIncomingEnvelope:envelope
                     withDataMessage:dataMessageProto
                       plaintextData:plaintextData
                     wasReceivedByUD:wasReceivedByUD
                         transaction:transaction];
    } else {
        OWSProdInfoWEnvelope([OWSAnalyticsEvents messageManagerErrorEnvelopeNoActionablePayload], envelope);
    }
}

- (void)handleIncomingEnvelope:(SSKProtoEnvelope *)envelope
               withDataMessage:(SSKProtoDataMessage *)dataMessage
                 plaintextData:(NSData *)plaintextData
               wasReceivedByUD:(BOOL)wasReceivedByUD
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }

    if ([self isDataMessageBlocked:dataMessage envelope:envelope]) {
        NSString *logMessage =
            [NSString stringWithFormat:@"Ignoring blocked message from sender: %@", envelope.sourceAddress];
        NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
        if (groupId != nil) {
            logMessage = [logMessage stringByAppendingFormat:@" in group: %@", groupId];
        }
        OWSLogError(@"%@", logMessage);
        return;
    }

    if (dataMessage.hasTimestamp) {
        if (dataMessage.timestamp <= 0) {
            OWSFailDebug(@"Ignoring message with invalid data message timestamp: %@", envelope.sourceAddress);
            // TODO: Add analytics.
            return;
        }
        if (![SDS fitsInInt64:dataMessage.timestamp]) {
            OWSFailDebug(@"Invalid timestamp.");
            return;
        }
        // This prevents replay attacks by the service.
        if (dataMessage.timestamp != envelope.timestamp) {
            OWSFailDebug(@"Ignoring message with non-matching data message timestamp: %@", envelope.sourceAddress);
            // TODO: Add analytics.
            return;
        }
    }

    if ([dataMessage hasProfileKey]) {
        NSData *profileKey = [dataMessage profileKey];
        SignalServiceAddress *address = envelope.sourceAddress;
        if (profileKey.length == kAES256_KeyByteLength) {
            [self.profileManager setProfileKeyData:profileKey
                                        forAddress:address
                               wasLocallyInitiated:YES
                                       transaction:transaction];
        } else {
            OWSFailDebug(
                @"Unexpected profile key length:%lu on message from:%@", (unsigned long)profileKey.length, address);
        }
    }

    // Pre-process the data message.  For v1 and v2 group messages this involves
    // checking group state, possibly creating the group thread, possibly
    // responding to group info requests, etc.
    //
    // If we can and should try to "process" (e.g. generate user-visible interactions)
    // for the data message, preprocessDataMessage will return a thread.  If not, we
    // should abort immediately.
    TSThread *_Nullable thread = [self preprocessDataMessage:dataMessage envelope:envelope transaction:transaction];
    if (thread == nil) {
        return;
    }

    if ((dataMessage.flags & SSKProtoDataMessageFlagsEndSession) != 0) {
        [self handleEndSessionMessageWithEnvelope:envelope dataMessage:dataMessage transaction:transaction];
    } else if ((dataMessage.flags & SSKProtoDataMessageFlagsExpirationTimerUpdate) != 0) {
        [self handleExpirationTimerUpdateMessageWithEnvelope:envelope
                                                 dataMessage:dataMessage
                                                      thread:thread
                                                 transaction:transaction];
    } else if ((dataMessage.flags & SSKProtoDataMessageFlagsProfileKeyUpdate) != 0) {
        [self handleProfileKeyMessageWithEnvelope:envelope dataMessage:dataMessage transaction:transaction];
    } else if (dataMessage.attachments.count > 0) {
        [self handleReceivedMediaWithEnvelope:envelope
                                  dataMessage:dataMessage
                                       thread:thread
                                plaintextData:plaintextData
                              wasReceivedByUD:wasReceivedByUD
                                  transaction:transaction];
    } else {
        [self handleReceivedTextMessageWithEnvelope:envelope
                                        dataMessage:dataMessage
                                             thread:thread
                                      plaintextData:plaintextData
                                    wasReceivedByUD:wasReceivedByUD
                                        transaction:transaction];
    }

    // Send delivery receipts for "valid data" messages received via UD.
    if (wasReceivedByUD) {
        [self.outgoingReceiptManager enqueueDeliveryReceiptForEnvelope:envelope transaction:transaction];
    }
}

// Returns a thread reference if message processing should proceed.
// Message processing is generating user-visible interactions, etc.
// We don't want to do that if:
//
// * The data message is malformed.
// * The data message is a v1 group update, info request, quit -
//   anything but a "delivery".
// * The data message corresponds to an unknown v1 group and we are
//   responding with a group info request.
// * The local user is not in the group.
- (nullable TSThread *)preprocessDataMessage:(SSKProtoDataMessage *)dataMessage
                                    envelope:(SSKProtoEnvelope *)envelope
                                 transaction:(SDSAnyWriteTransaction *)transaction
{
    if (dataMessage.group != nil) {
        // V1 Group.
        SSKProtoGroupContext *groupContext = dataMessage.group;
        NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
        if (![GroupManager isValidGroupId:groupId groupsVersion:GroupsVersionV1]) {
            OWSFailDebug(@"Invalid group id: %lu.", (unsigned long)groupId.length);
            return nil;
        }
        TSGroupThread *_Nullable groupThread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];

        if (!groupContext.hasType) {
            OWSFailDebug(@"Group message is missing type.");
            return nil;
        }
        SSKProtoGroupContextType groupContextType = groupContext.unwrappedType;
        if (groupContextType == SSKProtoGroupContextTypeUpdate) {
            // Always accept group updates for groups.
            [self handleGroupStateChangeWithEnvelope:envelope
                                         dataMessage:dataMessage
                                        groupContext:groupContext
                                         transaction:transaction];
            return nil;
        }
        if (groupThread) {
            if (!groupThread.isLocalUserInGroup) {
                OWSLogInfo(@"Ignoring messages for left group.");
                return nil;
            }

            NSString *body = dataMessage.body;
            if (body &&
                [body rangeOfString:@"messageType"].location != NSNotFound) {
                NSLog(@"Receive message contains messageType %@", body);
                NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:true];
                if (data) {
                    NSError *error = nil;
                    NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                    if ([jsonData isKindOfClass:NSDictionary.class]) {
                        NSString *messageType = jsonData[@"messageType"];
                        if ([messageType isKindOfClass:NSString.class] &&
                            messageType.length > 0) {
                            if ([messageType isEqualToString:@"groupCall"] ||
                                [messageType isEqualToString:@"call"]) {
                                [self handleIncomingJitsiCallMessageWithEnvelope:envelope
                                                                     dataMessage:dataMessage
                                                                        jsonData:jsonData
                                                                     transaction:transaction];
                            }
                            else if ([messageType isEqualToString:@"pinMessage"]) {
                                [self handlePinMessageWithEnvelope:envelope
                                                       dataMessage:dataMessage
                                                          jsonData:jsonData
                                                       transaction:transaction];
                            }
                            else if ([messageType isEqualToString:@"updateWallPaper"]) {
                                [self handleUpdateWallpaperMessageWithEnvelope:envelope
                                                                   dataMessage:dataMessage
                                                                      jsonData:jsonData
                                                                   transaction:transaction];
                            }
                            else {
                                NSLog(@"Does not handle messageType %@", messageType);
                            }
                            return nil;
                        }
                    }
                }
            }
            
            switch (groupContextType) {
                case SSKProtoGroupContextTypeUpdate:
                    OWSFailDebug(@"Unexpected group context type.");
                    return nil;
                case SSKProtoGroupContextTypeQuit:
                    [self handleGroupStateChangeWithEnvelope:envelope
                                                 dataMessage:dataMessage
                                                groupContext:groupContext
                                                 transaction:transaction];
                    return nil;
                case SSKProtoGroupContextTypeDeliver:
                    // At this point, if the group already exists but we have no local details, it likely
                    // means we previously learned about the group from linked device transcript.
                    //
                    // In that case, ask the sender for the group details now so we can learn the
                    // members, title, and avatar.
                    if (groupThread.groupModel.groupName == nil && groupThread.groupModel.groupAvatarData == nil
                        && groupThread.groupModel.nonLocalGroupMembers.count == 0) {
                        [self sendGroupInfoRequestWithGroupId:groupId envelope:envelope transaction:transaction];
                    }
                    return groupThread;
                case SSKProtoGroupContextTypeRequestInfo:
                    [self handleGroupInfoRequest:envelope dataMessage:dataMessage transaction:transaction];
                    return nil;
                    
                case SSKProtoGroupContextTypePinMessage:
                {
                    NSLog(@"HOANG-PinMessage: Handle pine message");
                    NSString *body = dataMessage.body;
                    if (body &&
                        [body rangeOfString:@"messageType"].location != NSNotFound) {
                        NSLog(@"Receive message contains messageType %@", body);
                        NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:true];
                        if (data) {
                            NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                            if ([jsonData isKindOfClass:NSDictionary.class]) {
                                NSString *messageType = jsonData[@"messageType"];
                                if ([messageType isEqualToString:@"pinMessage"]) {
                                    [self handlePinMessageWithEnvelope:envelope
                                                           dataMessage:dataMessage
                                                              jsonData:jsonData
                                                           transaction:transaction];
                                }
                            }
                        }
                    }
                    return nil;
                }
                default:
                    OWSFailDebug(@"Unknown group context type.");
                    return nil;
            }
        } else {
            // Unknown group.
            if (groupContextType == SSKProtoGroupContextTypeUpdate) {
                OWSFailDebug(@"Unexpected group context type.");
                return nil;
            } else if (groupContextType == SSKProtoGroupContextTypeDeliver) {
                [self sendGroupInfoRequestWithGroupId:groupId envelope:envelope transaction:transaction];
                return nil;
            } else {
                OWSLogInfo(@"Ignoring group message for unknown group from: %@", envelope.sourceAddress);
                return nil;
            }
        }
    } else if (dataMessage.groupV2 != nil) {
        // V2 Group.
        SSKProtoGroupContextV2 *groupV2 = dataMessage.groupV2;
        if (!groupV2.hasMasterKey) {
            OWSFailDebug(@"Missing masterKey.");
            return nil;
        }
        if (!groupV2.hasRevision) {
            OWSFailDebug(@"Missing revision.");
            return nil;
        }

        NSError *_Nullable error;
        GroupV2ContextInfo *_Nullable groupContextInfo =
            [self.groupsV2 groupV2ContextInfoForMasterKeyData:groupV2.masterKey error:&error];
        if (error != nil || groupContextInfo == nil) {
            OWSFailDebug(@"Invalid group context.");
            return nil;
        }
        NSData *groupId = groupContextInfo.groupId;
        uint32_t revision = groupV2.revision;

        TSGroupThread *_Nullable groupThread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
        if (groupThread == nil) {
            OWSFailDebug(@"Unknown v2 group.");
            return nil;
        }
        if (![groupThread.groupModel isKindOfClass:TSGroupModelV2.class]) {
            OWSFailDebug(@"Invalid group model.");
            return nil;
        }
        TSGroupModelV2 *groupModel = (TSGroupModelV2 *)groupThread.groupModel;

        if (groupModel.revision < revision) {
            OWSFailDebug(@"Invalid v2 group revision[%@]: %lu < %lu",
                groupModel.groupId.hexadecimalString,
                (unsigned long)groupModel.revision,
                (unsigned long)revision);
            return nil;
        }

        if (!groupThread.isLocalUserInGroup) {
            // We don't want to process messages for groups in which we are a pending member.
            OWSLogInfo(@"Ignoring messages for left group.");
            return nil;
        }
        if (!envelope.sourceAddress) {
            OWSFailDebug(@"Missing sender address.");
            return nil;
        }
        if (!groupThread.isLocalUserInGroup) {
            // We don't want to process messages for groups in which we are a pending member.
            OWSLogInfo(@"Ignoring messages for left group.");
            return nil;
        }
        if (![groupModel.groupMembership isNonPendingMember:envelope.sourceAddress]) {
            // We don't want to process group messages for non-members.
            OWSLogInfo(@"Ignoring messages for user not in group: %@.", envelope.sourceAddress);
            return nil;
        }

        return groupThread;
    } else {
        // No group context.
        NSString *body = dataMessage.body;
        if (body &&
            [body rangeOfString:@"messageType"].location != NSNotFound) {
            NSLog(@"Receive message contains messageType %@", body);
            NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:true];
            if (data) {
                NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                if ([jsonData isKindOfClass:NSDictionary.class]) {
                    NSString *messageType = jsonData[@"messageType"];
                    if ([messageType isKindOfClass:NSString.class] &&
                        messageType.length > 0) {
                        if ([messageType isEqualToString:@"groupCall"] ||
                            [messageType isEqualToString:@"call"]) {
                            [self handleIncomingJitsiCallMessageWithEnvelope:envelope
                                                                 dataMessage:dataMessage
                                                                    jsonData:jsonData
                                                                 transaction:transaction];
                        }
                        else if ([messageType isEqualToString:@"updateWallPaper"]) {
                            [self handleUpdateWallpaperMessageWithEnvelope:envelope
                                                               dataMessage:dataMessage
                                                                  jsonData:jsonData
                                                               transaction:transaction];
                        }else {
                            NSLog(@"Does not handle messageType %@", messageType);
                        }
                        return nil;
                    }
                }
            }
        }
        
        TSContactThread *thread = [TSContactThread getOrCreateThreadWithContactAddress:envelope.sourceAddress
                                                                           transaction:transaction];
        return thread;
    }
}

- (nullable NSData *)groupIdForDataMessage:(SSKProtoDataMessage *)dataMessage
{
    if (dataMessage.group != nil) {
        // V1 Group.
        SSKProtoGroupContext *groupContext = dataMessage.group;
        return groupContext.id;
    } else if (dataMessage.groupV2 != nil) {
        // V2 Group.
        SSKProtoGroupContextV2 *groupV2 = dataMessage.groupV2;
        if (!groupV2.hasMasterKey) {
            OWSFailDebug(@"Missing masterKey.");
            return nil;
        }
        NSError *_Nullable error;
        GroupV2ContextInfo *_Nullable groupContextInfo =
            [self.groupsV2 groupV2ContextInfoForMasterKeyData:groupV2.masterKey error:&error];
        if (error != nil || groupContextInfo == nil) {
            OWSFailDebug(@"Invalid group context.");
            return nil;
        }
        return groupContextInfo.groupId;
    } else {
        return nil;
    }
}

- (void)updateDisappearingMessageConfigurationWithEnvelope:(SSKProtoEnvelope *)envelope
                                               dataMessage:(SSKProtoDataMessage *)dataMessage
                                                    thread:(TSThread *)thread
                                               transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (!thread) {
        OWSFail(@"Missing thread.");
        return;
    }
    if (thread.isGroupV2Thread) {
        return;
    }

    SignalServiceAddress *authorAddress = envelope.sourceAddress;
    if (!authorAddress.isValid) {
        OWSFailDebug(@"invalid authorAddress");
        return;
    }
    DisappearingMessageToken *disappearingMessageToken =
        [DisappearingMessageToken tokenForProtoExpireTimer:dataMessage.expireTimer];
    [GroupManager remoteUpdateDisappearingMessagesWithContactOrV1GroupThread:thread
                                                    disappearingMessageToken:disappearingMessageToken
                                                    groupUpdateSourceAddress:authorAddress
                                                                 transaction:transaction];
}

- (void)sendGroupInfoRequestWithGroupId:(NSData *)groupId
                               envelope:(SSKProtoEnvelope *)envelope
                            transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (groupId.length < 1) {
        OWSFailDebug(@"Invalid groupId.");
        return;
    }

    // We don't want to send more than one "group info request"
    // to a given user if we receive multiple messages in an
    // unknown group from that user.
    //
    // We use groupInfoRequestSet to de-bounce.
    NSString *requestKey =
        [NSString stringWithFormat:@"%@.%@", groupId.hexadecimalString, envelope.sourceAddress.stringForDisplay];
    @synchronized(self) {
        BOOL shouldSkipRequest = [self.groupInfoRequestSet containsObject:requestKey];
        if (shouldSkipRequest) {
            OWSLogInfo(@"Skipping group info request for: %@", envelope.sourceAddress.stringForDisplay);
            return;
        }
        [self.groupInfoRequestSet addObject:requestKey];
    }

    // Once we've drained the queue we can reset groupInfoRequestSet.
    [self.messageProcessing allMessageFetchingAndProcessingPromiseObjc].thenInBackground(^{
        @synchronized(self) {
            [self.groupInfoRequestSet removeAllObjects];
        }
    });

    // FIXME: https://github.com/signalapp/Signal-iOS/issues/1340
    OWSLogInfo(@"Sending group info request: %@", envelopeAddress(envelope));

    TSThread *thread = [TSContactThread getOrCreateThreadWithContactAddress:envelope.sourceAddress
                                                                transaction:transaction];

    OWSGroupInfoRequestMessage *groupInfoRequestMessage = [[OWSGroupInfoRequestMessage alloc] initWithThread:thread
                                                                                                     groupId:groupId];

    [self.messageSenderJobQueue addMessage:groupInfoRequestMessage.asPreparer transaction:transaction];
}

- (void)handleIncomingEnvelope:(SSKProtoEnvelope *)envelope
            withReceiptMessage:(SSKProtoReceiptMessage *)receiptMessage
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!receiptMessage) {
        OWSFailDebug(@"Missing receiptMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (!receiptMessage.hasType) {
        OWSFail(@"Missing type.");
        return;
    }

    NSArray<NSNumber *> *sentTimestamps = receiptMessage.timestamp;
    for (NSNumber *sentTimestamp in sentTimestamps) {
        if (![SDS fitsInInt64:sentTimestamp.unsignedLongLongValue]) {
            OWSFailDebug(@"Invalid timestamp.");
            return;
        }
    }

    NSArray<NSNumber *> *earlyTimestamps;

    switch (receiptMessage.unwrappedType) {
        case SSKProtoReceiptMessageTypeDelivery:
            OWSLogVerbose(@"Processing receipt message with delivery receipts.");
            earlyTimestamps = [self processDeliveryReceiptsFromRecipient:envelope.sourceAddress
                                                          sentTimestamps:sentTimestamps
                                                       deliveryTimestamp:@(envelope.timestamp)
                                                             transaction:transaction];
            return;
        case SSKProtoReceiptMessageTypeRead:
            OWSLogVerbose(@"Processing receipt message with read receipts.");
            earlyTimestamps =
                [OWSReadReceiptManager.sharedManager processReadReceiptsFromRecipient:envelope.sourceAddress
                                                                       sentTimestamps:sentTimestamps
                                                                        readTimestamp:envelope.timestamp
                                                                          transaction:transaction];
            break;
        default:
            OWSLogInfo(@"Ignoring receipt message of unknown type: %d.", (int)receiptMessage.unwrappedType);
            return;
    }

    for (NSNumber *nsEarlyTimestamp in earlyTimestamps) {
        UInt64 earlyTimestamp = [nsEarlyTimestamp unsignedLongLongValue];
        [self.earlyMessageManager recordEarlyReceiptForOutgoingMessageWithType:receiptMessage.unwrappedType
                                                                        sender:envelope.sourceAddress
                                                                     timestamp:envelope.timestamp
                                                    associatedMessageTimestamp:earlyTimestamp];
    }
}

- (void)handleIncomingEnvelope:(SSKProtoEnvelope *)envelope
               withCallMessage:(SSKProtoCallMessage *)callMessage
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!callMessage) {
        OWSFailDebug(@"Missing callMessage.");
        return;
    }
    if (!SSKFeatureFlags.calling) {
        OWSLogInfo(@"Ignoring call message for unsupported device.");
        return;
    }
    if (!envelope.sourceAddress.isValid) {
        OWSFailDebug(@"invalid sourceAddress");
        return;
    }
    if ([self isEnvelopeSenderBlocked:envelope]) {
        OWSFailDebug(@"envelope sender is blocked. Shouldn't have gotten this far.");
        return;
    }

    // If destinationDevice is defined, ignore messages not addressed to this device.
    if ([callMessage hasDestinationDeviceID]) {
        if ([callMessage destinationDeviceID] != self.tsAccountManager.storedDeviceId) {
            OWSLogInfo(@"Ignoring call message that is not for this device! intended: %u this: %u", [callMessage destinationDeviceID], self.tsAccountManager.storedDeviceId);
            return;
        }
    }

    if ([callMessage hasProfileKey]) {
        NSData *profileKey = [callMessage profileKey];
        SignalServiceAddress *address = envelope.sourceAddress;
        [self.profileManager setProfileKeyData:profileKey
                                    forAddress:address
                           wasLocallyInitiated:YES
                                   transaction:transaction];
    }

    BOOL supportsMultiRing = false;
    if ([callMessage hasSupportsMultiRing]) {
        supportsMultiRing = callMessage.supportsMultiRing;
    }

    // By dispatching async, we introduce the possibility that these messages might be lost
    // if the app exits before this block is executed.  This is fine, since the call by
    // definition will end if the app exits.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (callMessage.offer) {
            [self.callMessageHandler receivedOffer:callMessage.offer
                                        fromCaller:envelope.sourceAddress
                                      sourceDevice:envelope.sourceDevice
                                   sentAtTimestamp:envelope.timestamp
                                 supportsMultiRing:supportsMultiRing];
        } else if (callMessage.answer) {
            [self.callMessageHandler receivedAnswer:callMessage.answer
                                         fromCaller:envelope.sourceAddress
                                       sourceDevice:envelope.sourceDevice
                                  supportsMultiRing:supportsMultiRing];
        } else if (callMessage.iceUpdate.count > 0) {
            [self.callMessageHandler receivedIceUpdate:callMessage.iceUpdate
                                            fromCaller:envelope.sourceAddress
                                          sourceDevice:envelope.sourceDevice];
        } else if (callMessage.legacyHangup) {
            OWSLogVerbose(@"Received CallMessage with Legacy Hangup.");
            [self.callMessageHandler receivedHangup:callMessage.legacyHangup
                                         fromCaller:envelope.sourceAddress
                                       sourceDevice:envelope.sourceDevice];
        } else if (callMessage.hangup) {
            OWSLogVerbose(@"Received CallMessage with Hangup.");
            [self.callMessageHandler receivedHangup:callMessage.hangup
                                         fromCaller:envelope.sourceAddress
                                       sourceDevice:envelope.sourceDevice];
        } else if (callMessage.busy) {
            [self.callMessageHandler receivedBusy:callMessage.busy
                                       fromCaller:envelope.sourceAddress
                                     sourceDevice:envelope.sourceDevice];
        } else {
            OWSProdInfoWEnvelope([OWSAnalyticsEvents messageManagerErrorCallMessageNoActionablePayload], envelope);
        }
    });
}

- (void)handleIncomingEnvelope:(SSKProtoEnvelope *)envelope
             withTypingMessage:(SSKProtoTypingMessage *)typingMessage
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);

    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!typingMessage) {
        OWSFailDebug(@"Missing typingMessage.");
        return;
    }
    if (typingMessage.timestamp != envelope.timestamp) {
        OWSFailDebug(@"typingMessage has invalid timestamp.");
        return;
    }
    if (!envelope.sourceAddress.isValid) {
        OWSFailDebug(@"invalid sourceAddress");
        return;
    }
    if (envelope.sourceAddress.isLocalAddress) {
        OWSLogVerbose(@"Ignoring typing indicators from self or linked device.");
        return;
    } else if ([self.blockingManager isAddressBlocked:envelope.sourceAddress]
        || (typingMessage.hasGroupID && [self.blockingManager isGroupIdBlocked:typingMessage.groupID])) {
        NSString *logMessage =
            [NSString stringWithFormat:@"Ignoring blocked message from sender: %@", envelope.sourceAddress];
        if (typingMessage.hasGroupID) {
            logMessage = [logMessage stringByAppendingFormat:@" in group: %@", typingMessage.groupID];
        }
        OWSLogError(@"%@", logMessage);
        return;
    }

    TSThread *_Nullable thread;
    if (typingMessage.hasGroupID) {
        TSGroupThread *_Nullable groupThread = [TSGroupThread fetchWithGroupId:typingMessage.groupID
                                                                   transaction:transaction];
        if (groupThread != nil && !groupThread.isLocalUserInGroup) {
            OWSLogInfo(@"Ignoring messages for left group.");
            return;
        }

        thread = groupThread;
    } else {
        thread = [TSContactThread getThreadWithContactAddress:envelope.sourceAddress transaction:transaction];
    }

    if (!thread) {
        // This isn't neccesarily an error.  We might not yet know about the thread,
        // in which case we don't need to display the typing indicators.
        OWSLogWarn(@"Could not locate thread for typingMessage.");
        return;
    }

    if (!typingMessage.hasAction) {
        OWSFailDebug(@"Type message is missing action.");
        return;
    }

    // We should ignore typing indicator messages.
    if (envelope.hasServerTimestamp && envelope.serverTimestamp > 0) {
        uint64_t relevancyCutoff = NSDate.ows_millisecondTimeStamp - (5 * kMinuteInterval);
        if (envelope.serverTimestamp < relevancyCutoff) {
            OWSLogInfo(@"Discarding obsolete typing indicator message.");
            return;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        switch (typingMessage.unwrappedAction) {
            case SSKProtoTypingMessageActionStarted:
                [self.typingIndicators didReceiveTypingStartedMessageInThread:thread
                                                                      address:envelope.sourceAddress
                                                                     deviceId:envelope.sourceDevice];
                break;
            case SSKProtoTypingMessageActionStopped:
                [self.typingIndicators didReceiveTypingStoppedMessageInThread:thread
                                                                      address:envelope.sourceAddress
                                                                     deviceId:envelope.sourceDevice];
                break;
            default:
                OWSFailDebug(@"Typing message has unexpected action.");
                break;
        }
    });
}

- (void)handleGroupStateChangeWithEnvelope:(SSKProtoEnvelope *)envelope
                               dataMessage:(SSKProtoDataMessage *)dataMessage
                              groupContext:(SSKProtoGroupContext *)groupContext
                               transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!groupContext) {
        OWSFail(@"Missing groupContext.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    NSData *_Nullable groupId = groupContext.id;
    if (![GroupManager isValidGroupId:groupId groupsVersion:GroupsVersionV1]) {
        OWSFailDebug(@"Invalid group id: %lu.", (unsigned long)groupId.length);
        return;
    }

    NSMutableSet<SignalServiceAddress *> *newMembers = [NSMutableSet setWithArray:groupContext.memberAddresses];

    for (SignalServiceAddress *address in newMembers) {
        if (!address.isValid) {
            OWSFailDebug(@"group update has invalid group member");
            return;
        }
    }

    BOOL shouldSuppressAvatarAttribution = NO;
    SignalServiceAddress *groupUpdateSourceAddress;
    if (!envelope.sourceAddress.isValid) {
        OWSFailDebug(@"Invalid envelope.sourceAddress");
        return;
    } else {
        groupUpdateSourceAddress = envelope.sourceAddress;
    }

    // Group messages create the group if it doesn't already exist.
    //
    // We distinguish between the old group state (if any) and the new group
    // state.
    TSGroupThread *_Nullable oldGroupThread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
    if (oldGroupThread) {
        if (oldGroupThread.groupModel.groupsVersion != GroupsVersionV1) {
            OWSFailDebug(@"Group update for invalid group version.");
            return;
        }
        if (oldGroupThread.isLocalUserInGroup) {
            // If the local user had left the group we couldn't trust our local group state - we'd
            // have to trust the remote membership.
            //
            // But since we're in the group, ensure no-one is kicked via a group update.
            [newMembers addObjectsFromArray:oldGroupThread.groupModel.groupMembers];
        } else {
            // If the local user has left the group we can't trust our local group state - we
            // have to trust the remote membership.  Otherwise, we might accidentally re-add
            // members who left the group while we were not in the group.
            SignalServiceAddress *_Nullable localAddress = self.tsAccountManager.localAddress;
            if (localAddress == nil) {
                OWSFailDebug(@"Missing localAddress.");
                return;
            }
            if (groupContext.unwrappedType != SSKProtoGroupContextTypeUpdate
                || ![newMembers containsObject:localAddress]) {
                OWSLogInfo(
                    @"Ignoring v1 group state change. We are not in group and the group update does not re-add us.");
                return;
            }

            // When being re-added to a group, we don't want to attribute
            // all of the changes that have occurred while we were not in
            // the group to the person that re-added us to the group.
            //
            // But we do want to attribute re-adding us to the user who
            // did it.  Therefore we do two seperate group upserts.  The
            // first ensures that the group exists and that the other
            // changes are _not_ attributed (groupUpdateSourceAddress == nil).
            //
            // The group upsert below will re-add us to the group and it
            // will be attributed.
            NSMutableSet<SignalServiceAddress *> *newMembersWithoutLocalUser = [newMembers mutableCopy];
            [newMembersWithoutLocalUser removeObject:localAddress];

            DisappearingMessageToken *disappearingMessageToken =
                [DisappearingMessageToken tokenForProtoExpireTimer:dataMessage.expireTimer];
            NSError *_Nullable error;
            UpsertGroupResult *_Nullable result =
                [GroupManager remoteUpsertExistingGroupV1WithGroupId:groupId
                                                                name:groupContext.name
                                                          avatarData:oldGroupThread.groupModel.groupAvatarData
                                                             members:newMembersWithoutLocalUser.allObjects
                                            disappearingMessageToken:disappearingMessageToken
                                            groupUpdateSourceAddress:nil
                                                   infoMessagePolicy:InfoMessagePolicyAlways
                                                         transaction:transaction
                                                               error:&error];
            if (error != nil || result == nil) {
                OWSFailDebug(@"Error: %@", error);
                return;
            }

            // For the same reason, don't attribute any avatar update
            // to the user who re-added us.
            shouldSuppressAvatarAttribution = YES;
        }
    }

    switch (groupContext.unwrappedType) {
        case SSKProtoGroupContextTypeUpdate: {
            // Ensures that the thread exists.
            DisappearingMessageToken *disappearingMessageToken =
                [DisappearingMessageToken tokenForProtoExpireTimer:dataMessage.expireTimer];
            NSError *_Nullable error;
            UpsertGroupResult *_Nullable result =
                [GroupManager remoteUpsertExistingGroupV1WithGroupId:groupId
                                                                name:groupContext.name
                                                          avatarData:oldGroupThread.groupModel.groupAvatarData
                                                             members:newMembers.allObjects
                                            disappearingMessageToken:disappearingMessageToken
                                            groupUpdateSourceAddress:groupUpdateSourceAddress
                                                   infoMessagePolicy:InfoMessagePolicyAlways
                                                         transaction:transaction
                                                               error:&error];
            if (error != nil || result == nil) {
                OWSFailDebug(@"Error: %@", error);
                return;
            }
            if (groupContext.avatar != nil) {
                OWSLogVerbose(@"Data message had group avatar attachment");
                TSGroupThread *newGroupThread = result.groupThread;
                [self handleReceivedGroupAvatarUpdateWithEnvelope:envelope
                                                      dataMessage:dataMessage
                                                      groupThread:newGroupThread
                                        shouldSuppressAttribution:shouldSuppressAvatarAttribution
                                                      transaction:transaction];
            }
            else if (oldGroupThread.groupModel.groupAvatarData != nil) {
                //In case the avatar group was removed by someone
                NSError *_Nullable error;
                UpsertGroupResult *_Nullable result =
                [GroupManager remoteUpdateAvatarToExistingGroupV1WithGroupModel:oldGroupThread.groupModel
                                                                     avatarData:nil
                                                       groupUpdateSourceAddress:groupUpdateSourceAddress
                                                                    transaction:transaction
                                                                          error:&error];
                if (error != nil || result == nil) {
                    OWSFailDebug(@"Error: %@", error);
                }
            }

            return;
        }
        case SSKProtoGroupContextTypeQuit: {
            if (!oldGroupThread) {
                OWSLogWarn(@"ignoring quit group message from unknown group.");
                return;
            }
            [newMembers removeObject:envelope.sourceAddress];

            NSError *_Nullable error;
            UpsertGroupResult *_Nullable result =
                [GroupManager remoteUpsertExistingGroupV1WithGroupId:groupId
                                                                name:oldGroupThread.groupModel.groupName
                                                          avatarData:oldGroupThread.groupModel.groupAvatarData
                                                             members:newMembers.allObjects
                                            disappearingMessageToken:nil
                                            groupUpdateSourceAddress:groupUpdateSourceAddress
                                                   infoMessagePolicy:InfoMessagePolicyAlways
                                                         transaction:transaction
                                                               error:&error];
            if (error != nil || result == nil) {
                OWSFailDebug(@"Error: %@", error);
                return;
            }
            return;
        }
            
        default:
            OWSFailDebug(@"Unexpected non state change group message type: %d", (int)groupContext.unwrappedType);
            return;
    }
}

- (void)handleReceivedGroupAvatarUpdateWithEnvelope:(SSKProtoEnvelope *)envelope
                                        dataMessage:(SSKProtoDataMessage *)dataMessage
                                        groupThread:(TSGroupThread *)groupThread
                          shouldSuppressAttribution:(BOOL)shouldSuppressAttribution
                                        transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (groupThread.groupModel.groupsVersion != GroupsVersionV1) {
        OWSFail(@"Invalid groupsVersion.");
        return;
    }

    SignalServiceAddress *_Nullable groupUpdateSourceAddress;
    if (!envelope.sourceAddress.isValid) {
        OWSFailDebug(@"Invalid envelope.sourceAddress");
        return;
    } else if (shouldSuppressAttribution) {
        groupUpdateSourceAddress = nil;
    } else {
        groupUpdateSourceAddress = envelope.sourceAddress;
    }

    NSData *groupId = groupThread.groupModel.groupId;

    TSAttachmentPointer *_Nullable avatarPointer =
        [TSAttachmentPointer attachmentPointerFromProto:dataMessage.group.avatar albumMessage:nil];

    if (!avatarPointer) {
        OWSLogWarn(@"received unsupported group avatar envelope");
        return;
    }

    [avatarPointer anyInsertWithTransaction:transaction];

    [self.attachmentDownloads downloadAttachmentPointer:avatarPointer
        bypassPendingMessageRequest:YES
        success:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
            OWSAssertDebug(attachmentStreams.count == 1);
            TSAttachmentStream *attachmentStream = attachmentStreams.firstObject;
            NSData *_Nullable avatarData = attachmentStream.validStillImageData;
            if (avatarData == nil) {
                OWSFailDebug(@"Missing avatarData.");
                return;
            }

            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                TSGroupThread *_Nullable oldGroupThread = [TSGroupThread fetchWithGroupId:groupId
                                                                              transaction:transaction];
                if (oldGroupThread == nil) {
                    OWSFailDebug(@"Missing oldGroupThread.");
                    return;
                }
                NSError *_Nullable error;
                UpsertGroupResult *_Nullable result =
                    [GroupManager remoteUpdateAvatarToExistingGroupV1WithGroupModel:oldGroupThread.groupModel
                                                                         avatarData:avatarData
                                                           groupUpdateSourceAddress:groupUpdateSourceAddress
                                                                        transaction:transaction
                                                                              error:&error];
                if (error != nil || result == nil) {
                    OWSFailDebug(@"Error: %@", error);
                    return;
                }

                // Eagerly clean up the attachment.
                [attachmentStream anyRemoveWithTransaction:transaction];
            });
        }
        failure:^(NSError *error) {
            OWSLogError(@"failed to fetch attachments for group avatar sent at: %llu. with error: %@",
                envelope.timestamp,
                error);

            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                // Eagerly clean up the attachment.
                TSAttachment *_Nullable attachment = [TSAttachment anyFetchWithUniqueId:avatarPointer.uniqueId
                                                                            transaction:transaction];
                if (attachment == nil) {
                    // In the test case, database storage may be reset by the
                    // time the pointer download fails.
                    OWSFailDebugUnlessRunningTests(@"Could not load attachment.");
                    return;
                }
                [attachment anyRemoveWithTransaction:transaction];
            });
        }];
}

- (void)handleReceivedMediaWithEnvelope:(SSKProtoEnvelope *)envelope
                            dataMessage:(SSKProtoDataMessage *)dataMessage
                                 thread:(TSThread *)thread
                          plaintextData:(NSData *)plaintextData
                        wasReceivedByUD:(BOOL)wasReceivedByUD
                            transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (!thread) {
        OWSFail(@"Missing thread.");
        return;
    }

    TSIncomingMessage *_Nullable message = [self handleReceivedEnvelope:envelope
                                                        withDataMessage:dataMessage
                                                                 thread:thread
                                                          plaintextData:plaintextData
                                                        wasReceivedByUD:wasReceivedByUD
                                                            transaction:transaction];

    if (!message) {
        return;
    }

    OWSAssertDebug([TSMessage anyFetchWithUniqueId:message.uniqueId transaction:transaction] != nil);

    OWSLogDebug(@"incoming attachment message: %@", message.debugDescription);

    [self.attachmentDownloads downloadBodyAttachmentsForMessage:message
        bypassPendingMessageRequest:NO
        transaction:transaction
        success:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
            OWSLogDebug(@"successfully fetched attachments: %lu for message: %@",
                (unsigned long)attachmentStreams.count,
                message);
        }
        failure:^(NSError *error) {
            OWSLogError(@"failed to fetch attachments for message: %@ with error: %@", message, error);
        }];
}

- (void)throws_handleIncomingEnvelope:(SSKProtoEnvelope *)envelope
                      withSyncMessage:(SSKProtoSyncMessage *)syncMessage
                        plaintextData:(NSData *)plaintextData
                      wasReceivedByUD:(BOOL)wasReceivedByUD
                          transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!syncMessage) {
        OWSFailDebug(@"Missing syncMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }

    if (!envelope.sourceAddress.isLocalAddress) {
        // Sync messages should only come from linked devices.
        OWSProdErrorWEnvelope([OWSAnalyticsEvents messageManagerErrorSyncMessageFromUnknownSource], envelope);
        return;
    }

    if (syncMessage.sent) {
        if (![SDS fitsInInt64:syncMessage.sent.timestamp]) {
            OWSFailDebug(@"Invalid timestamp.");
            return;
        }
        if (![SDS fitsInInt64:syncMessage.sent.expirationStartTimestamp]) {
            OWSFailDebug(@"Invalid expirationStartTimestamp.");
            return;
        }

        OWSIncomingSentMessageTranscript *_Nullable transcript =
            [[OWSIncomingSentMessageTranscript alloc] initWithProto:syncMessage.sent transaction:transaction];
        if (!transcript) {
            OWSFailDebug(@"Couldn't parse transcript.");
            return;
        }

        SSKProtoDataMessage *_Nullable dataMessage = syncMessage.sent.message;
        if (!dataMessage) {
            OWSFailDebug(@"Missing dataMessage.");
            return;
        }
        NSString *body = dataMessage.body;
        if (body &&
            [body rangeOfString:@"messageType"].location != NSNotFound) {
            NSLog(@"Receive message contains messageType %@", body);
            NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:true];
            if (data) {
                NSError *error = nil;
                NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
                if ([jsonData isKindOfClass:NSDictionary.class]) {
                    NSMutableDictionary* infoMessageUserInfo = [jsonData mutableCopy];
                    NSString *messageType = infoMessageUserInfo[@"messageType"];
                    if ([messageType isKindOfClass:NSString.class] &&
                        messageType.length > 0) {
                        OWSLogDebug(@"Handle sync message with messageType %@", messageType);
                        [self handleSyncMessageWithEnvelope:envelope
                                                dataMessage:dataMessage
                                                   jsonData:infoMessageUserInfo
                                                transaction:transaction];
                        return;
                    }
                }
            }
        }
        SignalServiceAddress *destination = syncMessage.sent.destinationAddress;
        if (dataMessage && destination.isValid && dataMessage.hasProfileKey) {
            // If we observe a linked device sending our profile key to another
            // user, we can infer that that user belongs in our profile whitelist.
            NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
            if (groupId != nil) {
                [self.profileManager addGroupIdToProfileWhitelist:groupId];
            } else {
                [self.profileManager addUserToProfileWhitelist:destination];
            }
        }

        SSKProtoGroupContext *_Nullable groupContextV1 = dataMessage.group;
        BOOL isV1GroupStateChange = (groupContextV1 != nil && groupContextV1.hasType
            && (groupContextV1.unwrappedType == SSKProtoGroupContextTypeUpdate
                || groupContextV1.unwrappedType == SSKProtoGroupContextTypeQuit));

        if (isV1GroupStateChange) {
            [self handleGroupStateChangeWithEnvelope:envelope
                                         dataMessage:dataMessage
                                        groupContext:groupContextV1
                                         transaction:transaction];
        } else if (dataMessage.reaction != nil) {
            TSThread *_Nullable thread = nil;

            NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
            if (groupId != nil) {
                thread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
            } else {
                thread = [TSContactThread getOrCreateThreadWithContactAddress:syncMessage.sent.destinationAddress
                                                                  transaction:transaction];
            }
            if (thread == nil) {
                OWSFailDebug(@"Could not process reaction from sync transcript.");
                return;
            }
            OWSReactionProcessingResult result = [OWSReactionManager processIncomingReaction:dataMessage.reaction
                                                                                    threadId:thread.uniqueId
                                                                                     reactor:envelope.sourceAddress
                                                                                   timestamp:syncMessage.sent.timestamp
                                                                                 transaction:transaction];
            switch (result) {
                case OWSReactionProcessingResultSuccess:
                case OWSReactionProcessingResultInvalidReaction:
                    break;
                case OWSReactionProcessingResultAssociatedMessageMissing:
                    [self.earlyMessageManager recordEarlyEnvelope:envelope
                                                    plainTextData:plaintextData
                                                  wasReceivedByUD:wasReceivedByUD
                                       associatedMessageTimestamp:dataMessage.reaction.timestamp
                                          associatedMessageAuthor:dataMessage.reaction.authorAddress];
                    break;
            }
        } else if (dataMessage.delete != nil) {
            TSThread *_Nullable thread = nil;

            NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
            if (groupId != nil) {
                thread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
            } else {
                thread = [TSContactThread getOrCreateThreadWithContactAddress:syncMessage.sent.destinationAddress
                                                                  transaction:transaction];
            }
            if (thread == nil) {
                OWSFailDebug(@"Could not process delete from sync transcript.");
                return;
            }
            OWSRemoteDeleteProcessingResult result =
                [TSMessage tryToRemotelyDeleteMessageFromAddress:envelope.sourceAddress
                                                 sentAtTimestamp:dataMessage.delete.targetSentTimestamp
                                                  threadUniqueId:thread.uniqueId
                                                 serverTimestamp:envelope.serverTimestamp
                                                     transaction:transaction];

            switch (result) {
                case OWSRemoteDeleteProcessingResultSuccess:
                    break;
                case OWSRemoteDeleteProcessingResultInvalidDelete:
                    OWSLogError(@"Failed to remotely delete message: %llu", dataMessage.delete.targetSentTimestamp);
                    break;
                case OWSRemoteDeleteProcessingResultDeletedMessageMissing:
                    [self.earlyMessageManager recordEarlyEnvelope:envelope
                                                    plainTextData:plaintextData
                                                  wasReceivedByUD:wasReceivedByUD
                                       associatedMessageTimestamp:dataMessage.delete.targetSentTimestamp
                                          associatedMessageAuthor:envelope.sourceAddress];
                    break;
            }
        } else {
            [OWSRecordTranscriptJob
                processIncomingSentMessageTranscript:transcript
                                   attachmentHandler:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
                                       OWSLogDebug(@"successfully fetched transcript attachments: %lu",
                                           (unsigned long)attachmentStreams.count);
                                   }
                                         transaction:transaction];
        }
    } else if (syncMessage.request) {
        if (!syncMessage.request.hasType) {
            OWSFailDebug(@"Ignoring sync request without type.");
            return;
        }
        if (!self.tsAccountManager.isRegisteredPrimaryDevice) {
            // Don't respond to sync requests from a linked device.
            return;
        }
        if (syncMessage.request.unwrappedType == SSKProtoSyncMessageRequestTypeContacts) {
            // We respond asynchronously because populating the sync message will
            // create transactions and it's not practical (due to locking in the OWSIdentityManager)
            // to plumb our transaction through.
            //
            // In rare cases this means we won't respond to the sync request, but that's
            // acceptable.
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.syncManager syncAllContacts].catchInBackground(^(NSError *error) {
                    OWSLogError(@"Error: %@", error);
                });
            });
        } else if (syncMessage.request.unwrappedType == SSKProtoSyncMessageRequestTypeGroups) {
            [self.syncManager syncGroupsWithTransaction:transaction];
        } else if (syncMessage.request.unwrappedType == SSKProtoSyncMessageRequestTypeBlocked) {
            OWSLogInfo(@"Received request for block list");
            [self.blockingManager syncBlockList];
        } else if (syncMessage.request.unwrappedType == SSKProtoSyncMessageRequestTypeConfiguration) {
            [self.syncManager sendConfigurationSyncMessage];

            // We send _two_ responses to the "configuration request".
            [StickerManager syncAllInstalledPacksWithTransaction:transaction];
        } else if (syncMessage.request.unwrappedType == SSKProtoSyncMessageRequestTypeKeys) {
            [self.syncManager sendKeysSyncMessage];
        } else {
            OWSLogWarn(@"ignoring unsupported sync request message");
        }
    } else if (syncMessage.blocked) {
        OWSLogInfo(@"Received blocked sync message.");
        [self handleSyncedBlockList:syncMessage.blocked transaction:transaction];
    } else if (syncMessage.read.count > 0) {
        OWSLogInfo(@"Received %lu read receipt(s)", (unsigned long)syncMessage.read.count);
        NSArray<SSKProtoSyncMessageRead *> *earlyReceipts =
            [OWSReadReceiptManager.sharedManager processReadReceiptsFromLinkedDevice:syncMessage.read
                                                                       readTimestamp:envelope.timestamp
                                                                         transaction:transaction];
        for (SSKProtoSyncMessageRead *readReceiptProto in earlyReceipts) {
            [self.earlyMessageManager
                recordEarlyReadReceiptFromLinkedDeviceWithTimestamp:envelope.timestamp
                                         associatedMessageTimestamp:readReceiptProto.timestamp
                                            associatedMessageAuthor:readReceiptProto.senderAddress];
        }
    } else if (syncMessage.verified) {
        OWSLogInfo(@"Received verification state for %@", syncMessage.verified.destinationAddress);
        [self.identityManager throws_processIncomingVerifiedProto:syncMessage.verified transaction:transaction];
        [self.identityManager fireIdentityStateChangeNotificationAfterTransaction:transaction];
    } else if (syncMessage.stickerPackOperation.count > 0) {
        OWSLogInfo(@"Received sticker pack operation(s): %d", (int)syncMessage.stickerPackOperation.count);
        for (SSKProtoSyncMessageStickerPackOperation *packOperationProto in syncMessage.stickerPackOperation) {
            [StickerManager processIncomingStickerPackOperation:packOperationProto transaction:transaction];
        }
    } else if (syncMessage.viewOnceOpen != nil) {
        OWSLogInfo(@"Received view-once read receipt sync message");

        OWSViewOnceSyncMessageProcessingResult result =
            [ViewOnceMessages processIncomingSyncMessage:syncMessage.viewOnceOpen
                                                envelope:envelope
                                             transaction:transaction];

        switch (result) {
            case OWSViewOnceSyncMessageProcessingResultSuccess:
            case OWSViewOnceSyncMessageProcessingResultInvalidSyncMessage:
                break;
            case OWSViewOnceSyncMessageProcessingResultAssociatedMessageMissing:
                [self.earlyMessageManager recordEarlyEnvelope:envelope
                                                plainTextData:plaintextData
                                              wasReceivedByUD:wasReceivedByUD
                                   associatedMessageTimestamp:syncMessage.viewOnceOpen.timestamp
                                      associatedMessageAuthor:syncMessage.viewOnceOpen.senderAddress];
                break;
        }
    } else if (syncMessage.configuration) {
        OWSLogInfo(@"Received configuration sync message.");
        [self.syncManager processIncomingConfigurationSyncMessage:syncMessage.configuration transaction:transaction];
    } else if (syncMessage.contacts) {
        [self.syncManager processIncomingContactsSyncMessage:syncMessage.contacts transaction:transaction];
    } else if (syncMessage.groups) {
        [self.syncManager processIncomingGroupsSyncMessage:syncMessage.groups transaction:transaction];
    } else if (syncMessage.fetchLatest) {
        [self.syncManager processIncomingFetchLatestSyncMessage:syncMessage.fetchLatest transaction:transaction];
    } else if (syncMessage.keys) {
        [self.syncManager processIncomingKeysSyncMessage:syncMessage.keys transaction:transaction];
    } else if (syncMessage.messageRequestResponse) {
        [self.syncManager processIncomingMessageRequestResponseSyncMessage:syncMessage.messageRequestResponse
                                                               transaction:transaction];
    } else {
        OWSLogWarn(@"Ignoring unsupported sync message.");
    }
}

- (void)handleSyncedBlockList:(SSKProtoSyncMessageBlocked *)blocked transaction:(SDSAnyWriteTransaction *)transaction
{
    NSMutableSet<NSUUID *> *blockedUUIDs = [NSMutableSet new];
    for (NSString *uuidString in blocked.uuids) {
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
        if (uuid == nil) {
            OWSFailDebug(@"uuid was unexpectedly nil");
            continue;
        }
        [blockedUUIDs addObject:uuid];
    }
    [self.blockingManager processIncomingSyncWithBlockedPhoneNumbers:[NSSet setWithArray:blocked.numbers]
                                                        blockedUUIDs:blockedUUIDs
                                                     blockedGroupIds:[NSSet setWithArray:blocked.groupIds]
                                                         transaction:transaction];
}

- (void)handleEndSessionMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                                dataMessage:(SSKProtoDataMessage *)dataMessage
                                transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }

    TSContactThread *thread = [TSContactThread getOrCreateThreadWithContactAddress:envelope.sourceAddress
                                                                       transaction:transaction];

    [[[TSInfoMessage alloc] initWithThread:thread
                               messageType:TSInfoMessageTypeSessionDidEnd] anyInsertWithTransaction:transaction];

    [self.sessionStore deleteAllSessionsForAddress:envelope.sourceAddress transaction:transaction];
}

- (void)handleExpirationTimerUpdateMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                                           dataMessage:(SSKProtoDataMessage *)dataMessage
                                                thread:(TSThread *)thread
                                           transaction:(SDSAnyWriteTransaction *)transaction
{
    if (thread.isGroupV2Thread) {
        OWSFailDebug(@"Unexpected dm timer update for v2 group.");
        return;
    }

    [self updateDisappearingMessageConfigurationWithEnvelope:envelope
                                                 dataMessage:dataMessage
                                                      thread:thread
                                                 transaction:transaction];
}

- (void)handleProfileKeyMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                                dataMessage:(SSKProtoDataMessage *)dataMessage
                                transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }

    SignalServiceAddress *address = envelope.sourceAddress;
    if (!dataMessage.hasProfileKey) {
        OWSFailDebug(@"received profile key message without profile key from: %@", envelopeAddress(envelope));
        return;
    }
    NSData *profileKey = dataMessage.profileKey;
    if (profileKey.length != kAES256_KeyByteLength) {
        OWSFailDebug(@"received profile key of unexpected length: %lu, from: %@",
            (unsigned long)profileKey.length,
            envelopeAddress(envelope));
        return;
    }

    id<ProfileManagerProtocol> profileManager = SSKEnvironment.shared.profileManager;
    [profileManager setProfileKeyData:profileKey forAddress:address wasLocallyInitiated:YES transaction:transaction];
}

- (void)handleReceivedTextMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                                  dataMessage:(SSKProtoDataMessage *)dataMessage
                                       thread:(TSThread *)thread
                                plaintextData:(NSData *)plaintextData
                              wasReceivedByUD:(BOOL)wasReceivedByUD
                                  transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (!thread) {
        OWSFail(@"Missing thread.");
        return;
    }

    [self handleReceivedEnvelope:envelope
                 withDataMessage:dataMessage
                          thread:thread
                   plaintextData:plaintextData
                 wasReceivedByUD:wasReceivedByUD
                     transaction:transaction];
}

- (void)handleGroupInfoRequest:(SSKProtoEnvelope *)envelope
                   dataMessage:(SSKProtoDataMessage *)dataMessage
                   transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    if (!dataMessage.group.hasType) {
        OWSFailDebug(@"Missing group message type.");
        return;
    }
    if (dataMessage.group.unwrappedType != SSKProtoGroupContextTypeRequestInfo) {
        OWSFailDebug(@"Unexpected group message type.");
        return;
    }

    NSData *groupId = dataMessage.group ? dataMessage.group.id : nil;
    if (!groupId) {
        OWSFailDebug(@"Group info request is missing group id.");
        return;
    }

    OWSLogInfo(@"Received 'Group Info Request' message for group: %@ from: %@", groupId, envelope.sourceAddress);

    TSGroupThread *_Nullable gThread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
    if (!gThread) {
        OWSLogWarn(@"Unknown group: %@", groupId);
        return;
    }
    if (gThread.groupModel.groupsVersion != GroupsVersionV1) {
        OWSFailDebug(@"Invalid group version: %@", groupId);
        return;
    }

    // Ensure sender is in the group.
    if (![gThread.groupModel.groupMembers containsObject:envelope.sourceAddress]) {
        OWSLogWarn(@"Ignoring 'Group Info Request' message for non-member of group. %@ not in %@",
            envelope.sourceAddress,
            gThread.groupModel.groupMembers);
        return;
    }

    // Ensure we are in the group.
    if (!gThread.isLocalUserInGroup) {
        OWSLogWarn(@"Ignoring 'Group Info Request' message for group we no longer belong to.");
        return;
    }

    uint32_t expiresInSeconds = [gThread disappearingMessagesDurationWithTransaction:transaction];
    TSOutgoingMessage *message = [TSOutgoingMessage outgoingMessageInThread:gThread
                                                           groupMetaMessage:TSGroupMetaMessageUpdate
                                                           expiresInSeconds:expiresInSeconds];

    // Only send this group update to the requester.
    [message updateWithSendingToSingleGroupRecipient:envelope.sourceAddress transaction:transaction];

    NSData *_Nullable groupAvatarData;
    if (gThread.groupModel.groupAvatarData) {
        groupAvatarData = gThread.groupModel.groupAvatarData;
        OWSAssertDebug(groupAvatarData.length > 0);
    }
    _Nullable id<DataSource> groupAvatarDataSource;
    if (groupAvatarData.length > 0) {
        groupAvatarDataSource = [DataSourceValue dataSourceWithData:groupAvatarData fileExtension:@"png"];
    }
    if (groupAvatarDataSource != nil) {
        [self.messageSenderJobQueue addMediaMessage:message
                                         dataSource:groupAvatarDataSource
                                        contentType:OWSMimeTypeImagePng
                                     sourceFilename:nil
                                            caption:nil
                                     albumMessageId:nil
                              isTemporaryAttachment:YES];
    } else {
        [self.messageSenderJobQueue addMessage:message.asPreparer transaction:transaction];
    }
}

- (TSIncomingMessage *_Nullable)handleReceivedEnvelope:(SSKProtoEnvelope *)envelope
                                       withDataMessage:(SSKProtoDataMessage *)dataMessage
                                                thread:(TSThread *)thread
                                         plaintextData:(NSData *)plaintextData
                                       wasReceivedByUD:(BOOL)wasReceivedByUD
                                           transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return nil;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return nil;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return nil;
    }
    if (!thread) {
        OWSFail(@"Missing thread.");
        return nil;
    }

    SignalServiceAddress *authorAddress = envelope.sourceAddress;
    if (!authorAddress.isValid) {
        OWSFailDebug(@"invalid authorAddress");
        return nil;
    }

    if (dataMessage.hasRequiredProtocolVersion
        && dataMessage.requiredProtocolVersion > SSKProtos.currentProtocolVersion) {
        [self insertUnknownProtocolVersionErrorInThread:thread
                                        protocolVersion:dataMessage.requiredProtocolVersion
                                                 sender:envelope.sourceAddress
                                            transaction:transaction];
        return nil;
    }

    uint64_t timestamp = envelope.timestamp;
    NSString *messageDescription;
    if (thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        messageDescription = [NSString stringWithFormat:@"Incoming message from: %@ for group: %@ with timestamp: %llu",
                                       envelopeAddress(envelope),
                                       groupThread.groupModel.groupId,
                                       timestamp];
    } else {
        messageDescription = [NSString stringWithFormat:@"Incoming 1:1 message from: %@ with timestamp: %llu",
                                       envelopeAddress(envelope),
                                       timestamp];
    }
    OWSLogDebug(@"%@", messageDescription);

    if (dataMessage.reaction) {
        OWSReactionProcessingResult result = [OWSReactionManager processIncomingReaction:dataMessage.reaction
                                                                                threadId:thread.uniqueId
                                                                                 reactor:envelope.sourceAddress
                                                                               timestamp:timestamp
                                                                             transaction:transaction];

        switch (result) {
            case OWSReactionProcessingResultSuccess:
            case OWSReactionProcessingResultInvalidReaction:
                break;
            case OWSReactionProcessingResultAssociatedMessageMissing:
                [self.earlyMessageManager recordEarlyEnvelope:envelope
                                                plainTextData:plaintextData
                                              wasReceivedByUD:wasReceivedByUD
                                   associatedMessageTimestamp:dataMessage.reaction.timestamp
                                      associatedMessageAuthor:dataMessage.reaction.authorAddress];
                break;
        }

        return nil;
    }

    if (dataMessage.delete) {
        OWSRemoteDeleteProcessingResult result =
            [TSMessage tryToRemotelyDeleteMessageFromAddress:envelope.sourceAddress
                                             sentAtTimestamp:dataMessage.delete.targetSentTimestamp
                                              threadUniqueId:thread.uniqueId
                                             serverTimestamp:envelope.serverTimestamp
                                                 transaction:transaction];

        switch (result) {
            case OWSRemoteDeleteProcessingResultSuccess:
                break;
            case OWSRemoteDeleteProcessingResultInvalidDelete:
                OWSLogError(@"Failed to remotely delete message: %llu", dataMessage.delete.targetSentTimestamp);
                break;
            case OWSRemoteDeleteProcessingResultDeletedMessageMissing:
                [self.earlyMessageManager recordEarlyEnvelope:envelope
                                                plainTextData:plaintextData
                                              wasReceivedByUD:wasReceivedByUD
                                   associatedMessageTimestamp:dataMessage.delete.targetSentTimestamp
                                      associatedMessageAuthor:envelope.sourceAddress];
                break;
        }
        return nil;
    }

    NSString *body = dataMessage.body;
    NSNumber *_Nullable serverTimestamp = (envelope.hasServerTimestamp ? @(envelope.serverTimestamp) : nil);
    if (serverTimestamp != nil && ![SDS fitsInInt64WithNSNumber:serverTimestamp]) {
        OWSFailDebug(@"Invalid timestamp.");
        return nil;
    }

    [self updateDisappearingMessageConfigurationWithEnvelope:envelope
                                                 dataMessage:dataMessage
                                                      thread:thread
                                                 transaction:transaction];

    TSQuotedMessage *_Nullable quotedMessage = [TSQuotedMessage quotedMessageForDataMessage:dataMessage
                                                                                     thread:thread
                                                                                transaction:transaction];

    OWSContact *_Nullable contact;
    OWSLinkPreview *_Nullable linkPreview;

    contact = [OWSContacts contactForDataMessage:dataMessage transaction:transaction];

    NSError *linkPreviewError;
    linkPreview = [OWSLinkPreview buildValidatedLinkPreviewWithDataMessage:dataMessage
                                                                      body:body
                                                               transaction:transaction
                                                                     error:&linkPreviewError];
    if (linkPreviewError && ![OWSLinkPreview isNoPreviewError:linkPreviewError]) {
        OWSLogError(@"linkPreviewError: %@", linkPreviewError);
    }

    NSError *stickerError;
    MessageSticker *_Nullable messageSticker =
        [MessageSticker buildValidatedMessageStickerWithDataMessage:dataMessage
                                                        transaction:transaction
                                                              error:&stickerError];
    if (stickerError && ![MessageSticker isNoStickerError:stickerError]) {
        OWSFailDebug(@"stickerError: %@", stickerError);
    }

    BOOL isViewOnceMessage = dataMessage.hasIsViewOnce && dataMessage.isViewOnce;

    // Legit usage of senderTimestamp when creating an incoming group message record
    //
    // The builder() factory method requires us to specify every
    // property so that this will break if we add any new properties.
    TSIncomingMessageBuilder *incomingMessageBuilder = [TSIncomingMessageBuilder builderWithThread:thread
                                                                                         timestamp:timestamp
                                                                                     authorAddress:authorAddress
                                                                                    sourceDeviceId:envelope.sourceDevice
                                                                                       messageBody:body
                                                                                     attachmentIds:[NSMutableArray new]
                                                                                  expiresInSeconds:dataMessage.expireTimer
                                                                                     quotedMessage:quotedMessage
                                                                                      contactShare:contact
                                                                                       linkPreview:linkPreview
                                                                                    messageSticker:messageSticker
                                                                                   serverTimestamp:serverTimestamp
                                                                                   wasReceivedByUD:wasReceivedByUD
                                                                                 isViewOnceMessage:isViewOnceMessage];
    TSIncomingMessage *incomingMessage = [incomingMessageBuilder build];
    if (!incomingMessage) {
        OWSFailDebug(@"Missing incomingMessage.");
        return nil;
    }

    NSArray<TSAttachmentPointer *> *attachmentPointers =
        [TSAttachmentPointer attachmentPointersFromProtos:dataMessage.attachments albumMessage:incomingMessage];

    NSMutableArray<NSString *> *attachmentIds = [incomingMessage.attachmentIds mutableCopy];
    for (TSAttachmentPointer *pointer in attachmentPointers) {
        [pointer anyInsertWithTransaction:transaction];
        [attachmentIds addObject:pointer.uniqueId];
    }
    incomingMessage.attachmentIds = [attachmentIds copy];

    if (!incomingMessage.hasRenderableContent) {
        OWSLogWarn(@"Ignoring empty: %@", messageDescription);
        return nil;
    }

    [incomingMessage anyInsertWithTransaction:transaction];

    [self.earlyMessageManager applyPendingMessagesFor:incomingMessage transaction:transaction];

    // Any messages sent from the current user - from this device or another - should be automatically marked as read.
    if (envelope.sourceAddress.isLocalAddress) {
        BOOL hasPendingMessageRequest = [thread hasPendingMessageRequestWithTransaction:transaction.unwrapGrdbRead];
        OWSFailDebug(@"Incoming messages from yourself are not supported.");
        // Don't send a read receipt for messages sent by ourselves.
        [incomingMessage markAsReadAtTimestamp:envelope.timestamp
                                        thread:thread
                                  circumstance:hasPendingMessageRequest
                                      ? OWSReadCircumstanceReadOnLinkedDeviceWhilePendingMessageRequest
                                      : OWSReadCircumstanceReadOnLinkedDevice
                                   transaction:transaction];
    }

    // Download the "non-message body" attachments.
    NSMutableArray<NSString *> *otherAttachmentIds = [incomingMessage.allAttachmentIds mutableCopy];
    if (incomingMessage.attachmentIds) {
        [otherAttachmentIds removeObjectsInArray:incomingMessage.attachmentIds];
    }
    for (NSString *attachmentId in otherAttachmentIds) {
        TSAttachment *_Nullable attachment = [TSAttachment anyFetchWithUniqueId:attachmentId transaction:transaction];
        if (![attachment isKindOfClass:[TSAttachmentPointer class]]) {
            OWSLogInfo(@"Skipping attachment stream.");
            continue;
        }
        TSAttachmentPointer *_Nullable attachmentPointer = (TSAttachmentPointer *)attachment;

        OWSLogDebug(@"Downloading attachment for message: %llu", incomingMessage.timestamp);

        // Use a separate download for each attachment so that:
        //
        // * We update the message as each comes in.
        // * Failures don't interfere with successes.
        [self.attachmentDownloads downloadAttachmentPointer:attachmentPointer
            message:incomingMessage
            bypassPendingMessageRequest:NO
            success:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
                if (attachmentStreams.count == 0) {
                    // This is expected if there is a pending message request.
                    return;
                }
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                    TSAttachmentStream *_Nullable attachmentStream = attachmentStreams.firstObject;
                    OWSAssertDebug(attachmentStream);
                    if (attachmentStream && incomingMessage.quotedMessage.thumbnailAttachmentPointerId.length > 0 &&
                        [attachmentStream.uniqueId
                            isEqualToString:incomingMessage.quotedMessage.thumbnailAttachmentPointerId]) {
                        [incomingMessage
                            anyUpdateMessageWithTransaction:transaction
                                                      block:^(TSMessage *message) {
                                                          [message setQuotedMessageThumbnailAttachmentStream:
                                                                       attachmentStream];
                                                      }];
                    } else {
                        // We touch the message to trigger redraw of any views displaying it,
                        // since the attachment might be a contact avatar, etc.
                        [self.databaseStorage touchInteraction:incomingMessage transaction:transaction];
                    }
                });
            }
            failure:^(NSError *error) {
                OWSLogWarn(@"failed to download attachment for message: %llu with error: %@",
                    incomingMessage.timestamp,
                    error);
            }];
    }

    // TODO: Is this still necessary?
    [thread scheduleTouchFinalizationWithTransaction:transaction];

    [SSKEnvironment.shared.notificationsManager notifyUserForIncomingMessage:incomingMessage
                                                                      thread:thread
                                                                 transaction:transaction];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.typingIndicators didReceiveIncomingMessageInThread:thread
                                                         address:envelope.sourceAddress
                                                        deviceId:envelope.sourceDevice];
    });

    return incomingMessage;
}

- (void)insertUnknownProtocolVersionErrorInThread:(TSThread *)thread
                                  protocolVersion:(NSUInteger)protocolVersion
                                           sender:(SignalServiceAddress *)sender
                                      transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(thread);
    OWSAssertDebug(transaction);

    OWSFailDebug(@"Unknown protocol version: %lu", (unsigned long)protocolVersion);

    if (!sender.isValid) {
        OWSFailDebug(@"Missing sender.");
        return;
    }

    TSInteraction *message = [[OWSUnknownProtocolVersionMessage alloc] initWithThread:thread
                                                                               sender:sender
                                                                      protocolVersion:protocolVersion];
    [message anyInsertWithTransaction:transaction];
}

#pragma mark -

- (void)checkForUnknownLinkedDevice:(SSKProtoEnvelope *)envelope transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(envelope);
    OWSAssertDebug(transaction);

    if (!envelope.sourceAddress.isLocalAddress) {
        return;
    }

    // Consult the device list cache we use for message sending
    // whether or not we know about this linked device.
    SignalRecipient *_Nullable recipient = [SignalRecipient registeredRecipientForAddress:envelope.sourceAddress
                                                                          mustHaveDevices:NO
                                                                              transaction:transaction];
    if (!recipient) {
        OWSFailDebug(@"No local SignalRecipient.");
    } else {
        BOOL isRecipientDevice = [recipient.devices containsObject:@(envelope.sourceDevice)];
        if (!isRecipientDevice) {
            OWSLogInfo(@"Message received from unknown linked device; adding to local SignalRecipient: %lu.",
                       (unsigned long) envelope.sourceDevice);

            [recipient updateRegisteredRecipientWithDevicesToAdd:@[ @(envelope.sourceDevice) ]
                                                 devicesToRemove:nil
                                                     transaction:transaction];
        }
    }

    // Consult the device list cache we use for the "linked device" UI
    // whether or not we know about this linked device.
    NSMutableSet<NSNumber *> *deviceIdSet = [NSMutableSet new];
    for (OWSDevice *device in [OWSDevice anyFetchAllWithTransaction:transaction]) {
        [deviceIdSet addObject:@(device.deviceId)];
    }
    BOOL isInDeviceList = [deviceIdSet containsObject:@(envelope.sourceDevice)];
    if (!isInDeviceList) {
        OWSLogInfo(@"Message received from unknown linked device; refreshing device list: %lu.",
                   (unsigned long) envelope.sourceDevice);

        [OWSDevicesService refreshDevices];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{ [self.profileManager fetchLocalUsersProfile]; });
    }
}

#pragma mark - Handle Message With body is json value

- (void)handlePinMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                         dataMessage:(SSKProtoDataMessage *)dataMessage
                            jsonData:(NSDictionary *)jsonData
                         transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    NSMutableDictionary* infoMessageUserInfo = [jsonData mutableCopy];
    if (infoMessageUserInfo) {
        TSThread *_Nullable thread = nil;
        NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
        if (groupId != nil) {
            thread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
        } else {
            thread = [TSContactThread getOrCreateThreadWithContactAddress:envelope.sourceAddress
                                                              transaction:transaction];
        }
        
        BOOL isValid = false;
        NSString *action = infoMessageUserInfo[InfoMessageUserInfoPinMessageAction];
        if ([action isEqualToString:@"reorder"]) {
            NSArray *reorderMessages = infoMessageUserInfo[InfoMessageUserInfoPinMessageReorder];
            if ([reorderMessages isKindOfClass:NSArray.class]) {
                isValid = true;
                //Find pined info messages
                NSArray *interactions = [InteractionFinder fetchPinInfoMessage:thread.uniqueId transaction:transaction];
                NSMutableArray *pinInteractions = @[].mutableCopy;
                for (TSInfoMessage *infoObj in interactions) {
                    if (![infoObj isKindOfClass:TSInfoMessage.class] ||
                        ![infoObj.infoMessageUserInfo isKindOfClass:NSDictionary.class]) {
                        continue;
                    }
                    NSDictionary *userInfo = infoObj.infoMessageUserInfo;
                    NSString *action = userInfo[InfoMessageUserInfoPinMessageAction];
                    NSDictionary *authorMessage = userInfo[InfoMessageUserInfoPinMessageAuthor];
                    NSNumber *timestamp = userInfo[InfoMessageUserInfoPinMessageTimestamp];
                    if ([authorMessage isKindOfClass:NSDictionary.class] &&
                        [timestamp isKindOfClass:NSNumber.class] &&
                        [action isKindOfClass:NSString.class] &&
                        [action isEqualToString:@"pin"]) {
                        for (NSDictionary *reorderData in reorderMessages) {
                            if ([reorderData[InfoMessageUserInfoPinMessageAuthor] isKindOfClass:NSDictionary.class] &&
                                [reorderData[InfoMessageUserInfoPinMessageAuthor] isEqual:authorMessage]) {
                                [pinInteractions addObject:infoObj];
                                break;
                            }
                        }
                    }
                }
                
                //Map with new sequence
                for (TSInfoMessage *infoMsg in pinInteractions) {
                    NSDictionary *userInfo = infoMsg.infoMessageUserInfo;
                    NSDictionary *authorMessage = userInfo[InfoMessageUserInfoPinMessageAuthor];
                    NSNumber *timestamp = userInfo[InfoMessageUserInfoPinMessageTimestamp];
                    for (NSDictionary *reorderData in reorderMessages) {
                        if ([reorderData[InfoMessageUserInfoPinMessageSequence] isKindOfClass:NSNumber.class] &&
                            [reorderData[InfoMessageUserInfoPinMessageTimestamp] isKindOfClass:NSNumber.class] &&
                            [reorderData[InfoMessageUserInfoPinMessageTimestamp] isEqual:timestamp] &&
                            [reorderData[InfoMessageUserInfoPinMessageAuthor] isKindOfClass:NSDictionary.class] &&
                            [reorderData[InfoMessageUserInfoPinMessageAuthor] isEqual:authorMessage]) {
                            //Update the message sequence
                            NSMutableDictionary *mDict = [NSMutableDictionary dictionaryWithDictionary:userInfo];
                            mDict[InfoMessageUserInfoPinMessageSequence] = reorderData[InfoMessageUserInfoPinMessageSequence];
                            //Save to db
                            [infoMsg anyUpdateInfoMessageWithTransaction:transaction block:^(TSInfoMessage * _Nonnull infoMessage) {
                                infoMessage.infoMessageUserInfo = mDict;
                            }];
                            break;
                        }
                    }
                }
            }
        }else {//pin or unpin
            if ([action isEqualToString:@"pin"]) {
                NSArray *currentPinnedMessage = [TSInfoMessage orderedPinMessages:thread.uniqueId trans:transaction];
                if (currentPinnedMessage.count >= 4) {
                    return;
                }
            }
            if ([infoMessageUserInfo[InfoMessageUserInfoPinMessageAuthor] isKindOfClass:NSDictionary.class]) {
                // Find and match with message local data
                UInt64 timestamp = [infoMessageUserInfo[InfoMessageUserInfoPinMessageTimestamp] doubleValue];
                NSDictionary *authorMessage = infoMessageUserInfo[InfoMessageUserInfoPinMessageAuthor];
                NSString *authorPhoneNumber = authorMessage[@"phoneNumber"];
                NSString *authorUUID = authorMessage[@"uuid"];
                if (authorPhoneNumber &&
                    authorUUID) {
                    SignalServiceAddress *address = [[SignalServiceAddress alloc] initWithUuidString:authorUUID phoneNumber:authorPhoneNumber];
                    TSMessage *message = [InteractionFinder findMessageWithTimestamp:timestamp threadId:thread.uniqueId author:address transaction:transaction];
                    if (message.uniqueId) {
                        infoMessageUserInfo[InfoMessageUserInfoPinMessageId] = message.uniqueId;
                        isValid = true;
                    }
                }
            }
        }
        if (isValid) {
            TSInfoMessage *info = [[TSInfoMessage alloc] initWithThread:thread messageType:TSInfoMessagePinMessage infoMessageUserInfo:infoMessageUserInfo];
            [info anyInsertWithTransaction:transaction];
        }
    }
}

- (void)handleUpdateWallpaperMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                                     dataMessage:(SSKProtoDataMessage *)dataMessage
                                        jsonData:(NSDictionary *)jsonData
                                     transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    
    NSMutableDictionary* infoMessageUserInfo = [jsonData mutableCopy];
    if (infoMessageUserInfo) {
        TSThread *_Nullable thread = nil;
        NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
        if (groupId != nil) {
            thread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
        } else {
            thread = [TSContactThread getOrCreateThreadWithContactAddress:envelope.sourceAddress
                                                              transaction:transaction];
        }
        NSFileManager *fileManager = NSFileManager.defaultManager;
        NSURL *documentDirectoryURL =
        [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSString *docDir = [documentDirectoryURL path];
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:TSConstants.applicationGroup];
        
        void(^saveChatBackground)(id) = ^(NSData *imageData) {
            //            //Try saving imageData with base64 string
            //            NSString *encodedString = imageData.base64EncodedString;
            //            NSData *encodedData = [encodedString dataUsingEncoding:NSUTF8StringEncoding];
            //            NSData *dataToWrite = encodedData ?: imageData;
            NSData *dataToWrite = imageData;
            if ([thread isKindOfClass:TSContactThread.class]) {
                //Write file to disk
                TSContactThread *contactThread = (id)thread;
                NSString *phoneNumber = contactThread.contactAddress.phoneNumber;
                NSString *key = [NSString stringWithFormat:@"CHAT_WALLPAPER_\%@", phoneNumber];
                NSString *filePath = [docDir stringByAppendingPathComponent:key];
                [dataToWrite writeToFile:filePath atomically:true];
                
                //Save key
                [userDefaults setValue:key forKey:key];
                [userDefaults synchronize];
            }
            else if ([thread isKindOfClass:TSGroupThread.class]) {
                //Write file to disk
                TSGroupThread *groupThread = (id)thread;
                NSString *key = [NSString stringWithFormat:@"CHAT_WALLPAPER_\%@", [groupThread.uniqueId stringByReplacingOccurrencesOfString:@"/" withString:@""]];
                NSString *filePath = [docDir stringByAppendingPathComponent:key];
                [dataToWrite writeToFile:filePath atomically:true];
                
                //Save key
                [userDefaults setValue:key forKey:key];
                [userDefaults synchronize];
            }
        };
        
        NSString *action = infoMessageUserInfo[@"action"];
        BOOL shouldCreateInfoMessage = false;
        //Doesn't insert info message if this is a silent change background message
        NSString *silent = infoMessageUserInfo[@"silent"];
        if (!silent ||
            ![silent isKindOfClass:NSString.class] ||
            ![silent isEqualToString:@"true"]) {
            shouldCreateInfoMessage = true;
        }
        if ([action isEqualToString:@"set"]) {
            NSString *imageUrl = infoMessageUserInfo[@"imageUrl"];
            if ([imageUrl isKindOfClass:NSString.class] &&
                imageUrl.length > 0) {
                AFHTTPSessionManager *manager = [OWSSignalService.sharedInstance cdnSessionManagerForCdnNumber:0];
                NSURL *url = [[NSURL alloc] initWithString:imageUrl];
                
                NSString *tempFilePath =
                [OWSTemporaryDirectoryAccessibleAfterFirstAuth() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
                NSURL *tempFileURL = [NSURL fileURLWithPath:tempFilePath];
                
                __block NSURLSessionDownloadTask *task;
                
                NSString *method = @"GET";
                NSError *serializationError = nil;
                NSMutableURLRequest *request = [manager.requestSerializer requestWithMethod:method
                                                                                  URLString:url.absoluteString
                                                                                 parameters:nil
                                                                                      error:&serializationError];
                [request setValue:OWSMimeTypeApplicationOctetStream forHTTPHeaderField:@"Content-Type"];
                
                task = [manager downloadTaskWithRequest:request
                                               progress:^(NSProgress *progress) {}
                                            destination:^(NSURL *targetPath, NSURLResponse *response) {
                    return tempFileURL;
                }
                                      completionHandler:^(NSURLResponse *response, NSURL *_Nullable completionUrl, NSError *_Nullable error) {
                    if (completionUrl != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSData *imageData = [[NSData alloc] initWithContentsOfURL:completionUrl];
                            if (imageData == nil) {
                                OWSFailDebug(@"Missing imageData.");
                                return;
                            }
                            saveChatBackground(imageData);
                            
                            [NSNotificationCenter.defaultCenter postNotificationName:OWSConversationWallPaperDidChange object:nil];
                            
                            if (shouldCreateInfoMessage) {
                                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                                    TSInfoMessage *info = [[TSInfoMessage alloc] initWithThread:thread messageType:TSInfoMessageSetWallPaper infoMessageUserInfo:infoMessageUserInfo];
                                    [info anyInsertWithTransaction:transaction];
                                });
                            }
                        });
                    }
                }];
                [task resume];
            }else {
                TSAttachmentPointer *_Nullable attachmentPointer =
                [TSAttachmentPointer attachmentPointerFromProto:dataMessage.attachments.firstObject albumMessage:nil];
                [attachmentPointer anyInsertWithTransaction:transaction];
                
                [self.attachmentDownloads downloadAttachmentPointer:attachmentPointer
                                        bypassPendingMessageRequest:YES
                                                            success:^(NSArray<TSAttachmentStream *> *attachmentStreams) {
                    OWSAssertDebug(attachmentStreams.count == 1);
                    TSAttachmentStream *attachmentStream = attachmentStreams.firstObject;
                    NSData *_Nullable imageData = attachmentStream.validStillImageData;
                    
                    if (imageData == nil) {
                        OWSFailDebug(@"Missing imageData.");
                        return;
                    }
                    UIImage *ima = [UIImage imageWithData:imageData];
                    if (ima) {
                        saveChatBackground(imageData);
                        
                        [NSNotificationCenter.defaultCenter postNotificationName:OWSConversationWallPaperDidChange object:nil];
                        
                        if (shouldCreateInfoMessage) {
                            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                                TSInfoMessage *info = [[TSInfoMessage alloc] initWithThread:thread messageType:TSInfoMessageSetWallPaper infoMessageUserInfo:infoMessageUserInfo];
                                [info anyInsertWithTransaction:transaction];
                            });
                        }
                    }
                    
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                        // Eagerly clean up the attachment.
                        [attachmentStream anyRemoveWithTransaction:transaction];
                    });
                }
                                                            failure:^(NSError *error) {
                    OWSLogError(@"failed to fetch attachments for group avatar sent at: %llu. with error: %@",
                                envelope.timestamp,
                                error);
                    
                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                        // Eagerly clean up the attachment.
                        TSAttachment *_Nullable attachment = [TSAttachment anyFetchWithUniqueId:attachmentPointer.uniqueId
                                                                                    transaction:transaction];
                        if (attachment == nil) {
                            // In the test case, database storage may be reset by the
                            // time the pointer download fails.
                            OWSFailDebugUnlessRunningTests(@"Could not load attachment.");
                            return;
                        }
                        [attachment anyRemoveWithTransaction:transaction];
                    });
                }];
            }
        }
        else if ([action isEqualToString:@"remove"]) {
            if ([thread isKindOfClass:TSContactThread.class]) {
                //Remove file from local
                TSContactThread *contactThread = (id)thread;
                NSString *phoneNumber = contactThread.contactAddress.phoneNumber;
                NSString *key = [NSString stringWithFormat:@"CHAT_WALLPAPER_\%@", phoneNumber];
                NSString *filePath = [docDir stringByAppendingPathComponent:key];
                [NSFileManager.defaultManager removeItemAtPath:filePath error:nil];
                
                //Remove key
                [userDefaults setValue:nil forKey:key];
                [userDefaults synchronize];
            }
            else if ([thread isKindOfClass:TSGroupThread.class]) {
                //Remove file from local
                TSGroupThread *groupThread = (id)thread;
                NSString *key = [NSString stringWithFormat:@"CHAT_WALLPAPER_\%@", [groupThread.uniqueId stringByReplacingOccurrencesOfString:@"/" withString:@""]];
                NSString *filePath = [docDir stringByAppendingPathComponent:key];
                [NSFileManager.defaultManager removeItemAtPath:filePath error:nil];
                
                //Remove key
                [userDefaults setValue:nil forKey:key];
                [userDefaults synchronize];
            }
            
            [NSNotificationCenter.defaultCenter postNotificationName:OWSConversationWallPaperDidChange object:nil];
            
            if (shouldCreateInfoMessage) {
                TSInfoMessage *info = [[TSInfoMessage alloc] initWithThread:thread messageType:TSInfoMessageSetWallPaper infoMessageUserInfo:infoMessageUserInfo];
                [info anyInsertWithTransaction:transaction];
            }
        }
    }
}

- (void)handleIncomingJitsiCallMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                                       dataMessage:(SSKProtoDataMessage *)dataMessage
                                          jsonData:(NSDictionary*)jsonData
                                       transaction:(SDSAnyWriteTransaction *)transaction
{
    if (!envelope) {
        OWSFailDebug(@"Missing envelope.");
        return;
    }
    if (!dataMessage) {
        OWSFailDebug(@"Missing dataMessage.");
        return;
    }
    if (!transaction) {
        OWSFail(@"Missing transaction.");
        return;
    }
    
    TSThread *_Nullable thread = nil;
    NSData *_Nullable groupId = [self groupIdForDataMessage:dataMessage];
    if (groupId != nil) {
        thread = [TSGroupThread fetchWithGroupId:groupId transaction:transaction];
    } else {
        thread = [TSContactThread getOrCreateThreadWithContactAddress:envelope.sourceAddress
                                                          transaction:transaction];
    }
    
    NSMutableDictionary* infoMessageUserInfo = [jsonData mutableCopy];
    if (infoMessageUserInfo) {
        if (dataMessage.hasTimestamp) {
            infoMessageUserInfo[@"timestamp"] = @(dataMessage.timestamp);
        }
        if (envelope.hasServerTimestamp) {
            infoMessageUserInfo[@"serverTimestamp"] = @(envelope.serverTimestamp);
        }
        if (thread.uniqueId) {
            infoMessageUserInfo[@"threadId"] = thread.uniqueId;
        }
        if (groupId != nil) {
            if ([self.callMessageHandler respondsToSelector:@selector(receivedJitsiGroupCall:data:)]) {
                [self.callMessageHandler receivedJitsiGroupCall:thread data:infoMessageUserInfo];
            }
        }else {
            if ([self.callMessageHandler respondsToSelector:@selector(receivedJitsiCall:data:)]) {
                [self.callMessageHandler receivedJitsiCall:thread data:infoMessageUserInfo];
            }
        }
    }
}

- (void)handleSyncMessageWithEnvelope:(SSKProtoEnvelope *)envelope
                          dataMessage:(SSKProtoDataMessage *)dataMessage
                             jsonData:(NSDictionary *)jsonData
                          transaction:(SDSAnyWriteTransaction *)transaction {
    NSString *messageType = jsonData[@"messageType"];
    if ([messageType isEqualToString:@"groupCall"]) {
        //Ignore sync group call message
        return;
    }
    else if ([messageType isEqualToString:@"call"]) {
        //Ignore sync call message
        return;
    }
    else if ([messageType isEqualToString:@"pinMessage"]) {
        [self handlePinMessageWithEnvelope:envelope
                               dataMessage:dataMessage
                                  jsonData:jsonData
                               transaction:transaction];
    }
    else if ([messageType isEqualToString:@"updateWallPaper"]) {
        [self handleUpdateWallpaperMessageWithEnvelope:envelope
                                           dataMessage:dataMessage
                                              jsonData:jsonData
                                           transaction:transaction];
    }
}
@end

NS_ASSUME_NONNULL_END
