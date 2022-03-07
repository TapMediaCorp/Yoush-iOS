//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public extension TSInfoMessage {

    // MARK: - Dependencies

    private var contactsManager: ContactsManagerProtocol {
        return SSKEnvironment.shared.contactsManager
    }

    private var tsAccountManager: TSAccountManager {
        return TSAccountManager.sharedInstance()
    }

    // MARK: -

    func groupUpdateDescription(transaction: SDSAnyReadTransaction) -> String {
        // for legacy group updates we persisted a pre-rendered string, rather than the details
        // to generate that string
        if let customMessage = self.customMessage {
            return customMessage
        }

        guard let newGroupModel = self.newGroupModel else {
            // Legacy info message before we began embedding user info.
            return GroupUpdateCopy.defaultGroupUpdateDescription(groupUpdateSourceAddress: groupUpdateSourceAddress,
                                                                 transaction: transaction)
        }

        return groupUpdateDescription(oldGroupModel: self.previousGroupModel,
                                      newGroupModel: newGroupModel,
                                      transaction: transaction)
    }

    func profileChangeDescription(transaction: SDSAnyReadTransaction) -> String {
        guard let profileChanges = profileChanges,
            let updateDescription = profileChanges.descriptionForUpdate(transaction: transaction) else {
                owsFailDebug("Unexpectedly missing update description for profile change")
            return ""
        }

        return updateDescription
    }

    var profileChangeAddress: SignalServiceAddress? {
        return profileChanges?.address
    }

    var profileChangeNewNameComponents: PersonNameComponents? {
        return profileChanges?.newNameComponents
    }
}

// MARK: -

extension TSInfoMessage {
    private func groupUpdateDescription(oldGroupModel: TSGroupModel?,
                                        newGroupModel: TSGroupModel,
                                        transaction: SDSAnyReadTransaction) -> String {

        guard let localAddress = tsAccountManager.localAddress else {
            owsFailDebug("missing local address")
            return GroupUpdateCopy.defaultGroupUpdateDescription(groupUpdateSourceAddress: groupUpdateSourceAddress,
                                                                 transaction: transaction)
        }

        let groupUpdate = GroupUpdateCopy(newGroupModel: newGroupModel,
                                          oldGroupModel: oldGroupModel,
                                          oldDisappearingMessageToken: oldDisappearingMessageToken,
                                          newDisappearingMessageToken: newDisappearingMessageToken,
                                          localAddress: localAddress,
                                          groupUpdateSourceAddress: groupUpdateSourceAddress,
                                          transaction: transaction)
        return groupUpdate.updateDescription
    }

    @objc
    public static func legacyDisappearingMessageUpdateDescription(token newToken: DisappearingMessageToken,
                                                                  wasAddedToExistingGroup: Bool,
                                                                  updaterName: String?) -> String {

        // This might be zero if DMs are not enabled.
        let durationString = NSString.formatDurationSeconds(newToken.durationSeconds, useShortFormat: false)

        if wasAddedToExistingGroup {
            assert(newToken.isEnabled)
            let format = NSLocalizedString("DISAPPEARING_MESSAGES_CONFIGURATION_GROUP_EXISTING_FORMAT",
                                           comment: "Info Message when added to a group which has enabled disappearing messages. Embeds {{time amount}} before messages disappear. See the *_TIME_AMOUNT strings for context.")
            return String(format: format, durationString)
        } else if let updaterName = updaterName {
            if newToken.isEnabled {
                let format = NSLocalizedString("OTHER_UPDATED_DISAPPEARING_MESSAGES_CONFIGURATION",
                                               comment: "Info Message when another user enabled disappearing messages. Embeds {{name of other user}} and {{time amount}} before messages disappear. See the *_TIME_AMOUNT strings for context.")
                return String(format: format, updaterName, durationString)
            } else {
                let format = NSLocalizedString("OTHER_DISABLED_DISAPPEARING_MESSAGES_CONFIGURATION",
                                               comment: "Info Message when another user disabled disappearing messages. Embeds {{name of other user}}.")
                return String(format: format, updaterName)
            }
        } else {
            // Changed by localNumber on this device or via synced transcript
            if newToken.isEnabled {
                let format = NSLocalizedString("YOU_UPDATED_DISAPPEARING_MESSAGES_CONFIGURATION",
                                               comment: "Info Message when you disabled disappearing messages. Embeds a {{time amount}} before messages disappear. see the *_TIME_AMOUNT strings for context.")
                return String(format: format, durationString)
            } else {
                return NSLocalizedString("YOU_DISABLED_DISAPPEARING_MESSAGES_CONFIGURATION",
                                         comment: "Info Message when you disabled disappearing messages.")
            }
        }
    }
}

// MARK: -

extension TSInfoMessage {

    private func infoMessageValue<T>(forKey key: InfoMessageUserInfoKey) -> T? {
        guard let infoMessageUserInfo = self.infoMessageUserInfo else {
            return nil
        }

        guard let groupModel = infoMessageUserInfo[key] as? T else {
            assert(infoMessageUserInfo[key] == nil)
            return nil
        }

        return groupModel
    }

    fileprivate var previousGroupModel: TSGroupModel? {
        return infoMessageValue(forKey: .oldGroupModel)
    }

    fileprivate var newGroupModel: TSGroupModel? {
        return infoMessageValue(forKey: .newGroupModel)
    }

    fileprivate var oldDisappearingMessageToken: DisappearingMessageToken? {
        return infoMessageValue(forKey: .oldDisappearingMessageToken)
    }

    fileprivate var newDisappearingMessageToken: DisappearingMessageToken? {
        return infoMessageValue(forKey: .newDisappearingMessageToken)
    }

    fileprivate var groupUpdateSourceAddress: SignalServiceAddress? {
        return infoMessageValue(forKey: .groupUpdateSourceAddress)
    }

    fileprivate var profileChanges: ProfileChanges? {
        return infoMessageValue(forKey: .profileChanges)
    }
}

//MARK: Pin message
@objc public
extension TSInfoMessage {
    class func orderedPinMessages(_ threadId:String, trans: SDSAnyReadTransaction) -> [TSInfoMessage] {
        var items = [String: [TSInfoMessage]]()
        var pinInfoMessages = [TSInfoMessage]()
        let interactions = InteractionFinder.fetchPinInfoMessage(threadId, transaction: trans)
        for viewItem in interactions {
            guard let infoMsg = viewItem as? TSInfoMessage,
                  let message = infoMsg.message(trans: trans),
                  message.wasRemotelyDeleted == false,//should check whether the message was deleted or not
                  let messageId = infoMsg.infoMessageUserInfo?[.pinMessageId] as? String else {
                continue
            }
            let action = infoMsg.pinMessageAction
            if action == PinMessageAction.pin.rawValue ||
                action == PinMessageAction.unpin.rawValue {
                var pinItemsForMessage = items[messageId]
                if pinItemsForMessage == nil {
                    pinItemsForMessage = [TSInfoMessage]()
                }
                pinItemsForMessage?.append(infoMsg)
                items[messageId] = pinItemsForMessage!
            }
        }
        for pinItemsForMessage in items.values {
            for infoMsg in pinItemsForMessage {
                let action = infoMsg.pinMessageAction
                if action == PinMessageAction.pin.rawValue {
                    //The last pin action is pin
                    pinInfoMessages.append(infoMsg)
                    break
                }
                else if action == PinMessageAction.unpin.rawValue {
                    //The last pin action is unpin
                    break
                }
            }
        }
        pinInfoMessages.sort(by: {$0.pinMessageSequence > $1.pinMessageSequence})
        return pinInfoMessages
    }
    

    func pinMessagePreviewText(trans: SDSAnyReadTransaction) -> String {
        guard let ownerAction = ownerActionAddress,
              let localAddress = TSAccountManager.sharedInstance().localAddress else {
            return ""
        }
        var userName = ""
        var action = ""
        
        if ownerAction == localAddress {
            userName = NSLocalizedString("GROUP_MEMBER_LOCAL_USER",
                                                 comment: "Label indicating the local user.")
        }else {
            userName = ownerActionName(ownerAction, trans: trans) ?? ""
        }
        
        if pinMessageAction == PinMessageAction.reorder.rawValue {
            action = NSLocalizedString("PIN_ACTION_REORDER",
                                       comment: "")
            return "\(userName) \(action)"
        }
        else if pinMessageAction == PinMessageAction.pin.rawValue {
            action = NSLocalizedString("PINNED_TITLE",
                                       comment: "")
        }else  {
            action = NSLocalizedString("UNPINNED_TITLE",
                                       comment: "")
        }
        var msgContent = ""
        if let message = message(trans: trans) {
            msgContent = message.body ?? ""
            let mediaAttachments = message.mediaAttachments(with: trans.unwrapGrdbRead)
            if msgContent.isEmpty ||
                mediaAttachments.count > 0 {
                //Check the message type
                var messageType = ""
                var bodyText = ""
                var cachedAttatchMent:TSAttachmentStream?
                //Reference albumItemsForMediaAttachments of ConversationInteractionViewItem
//                let mediaAttachments = message.mediaAttachments(with: trans.unwrapGrdbRead)
                if  mediaAttachments.count > 0 {
                    messageType = NSLocalizedString("PIN_MESSAGE_TYPE_A_PHOTO", comment: "")
                    for attachment in mediaAttachments {
                        if !attachment.isVisualMedia {
                            messageType = ""
                            break
                        }
                        if let attachmentStream = attachment as? TSAttachmentStream {
                            cachedAttatchMent = attachmentStream
                        }
                    }
                    if messageType == "" {
                        if let mediaAttachment = mediaAttachments.first {
                            if let attachmentStream = mediaAttachment as? TSAttachmentStream {
                                cachedAttatchMent = attachmentStream
                                if attachmentStream.isAudio {
                                    let audioDuration = attachmentStream.audioDurationSeconds()
                                    messageType = audioDuration > 0 ? NSLocalizedString("PIN_MESSAGE_TYPE_AN_AUDIO", comment: "") : NSLocalizedString("PIN_MESSAGE_TYPE_A_FILE", comment: "")
                                }else {
                                    messageType = NSLocalizedString("PIN_MESSAGE_TYPE_A_FILE", comment: "")
                                }
                                bodyText = attachmentStream.sourceFilename ?? ""
                            }
                            else if let attachmentPointer = mediaAttachment as? TSAttachmentPointer {
                                messageType = attachmentPointer.isAudio ? NSLocalizedString("PIN_MESSAGE_TYPE_AN_AUDIO", comment: "") : NSLocalizedString("PIN_MESSAGE_TYPE_A_FILE", comment: "")
                            }
                        }
                    }
                    else if cachedAttatchMent != nil {
                        if cachedAttatchMent!.isVideo {
                            messageType = NSLocalizedString("PIN_MESSAGE_TYPE_A_VIDEO", comment: "")
                        }
                        else if cachedAttatchMent!.isAudio {
                            messageType = NSLocalizedString("PIN_MESSAGE_TYPE_AN_AUDIO", comment: "")
                        }
                        else if cachedAttatchMent!.isImage {
                            messageType = NSLocalizedString("PIN_MESSAGE_TYPE_A_PHOTO", comment: "")
                        }
                        else if cachedAttatchMent!.isAnimated {
                            messageType = NSLocalizedString("PIN_MESSAGE_TYPE_A_GIFF", comment: "")
                        }else {
                            messageType = NSLocalizedString("PIN_MESSAGE_TYPE_A_FILE", comment: "")
                        }
                    }
                }
                if messageType.count > 0 {
                    return "\(userName) \(action) \(messageType)"
                }
            }
        }
        
        return "\(userName) \(action) \(NSLocalizedString("MESSAGE_METADATA_VIEW_TITLE", comment: "").lowercased()): '\(msgContent)'"
    }
    
    func message(trans: SDSAnyReadTransaction) -> TSMessage? {
        guard let userInfo = infoMessageUserInfo,
              let timestamp = userInfo[.pinMessageTimestamp] as? UInt64,
              let threadId = userInfo[.pinMessageGroupId] as? String,
              let msssageId = userInfo[.pinMessageId] as? String,
              let address = authorMessageAddress else {
            return nil
        }
        var message = TSMessage.anyFetchMessage(uniqueId: msssageId, transaction: trans)
        if message == nil {
            message = InteractionFinder.findMessage(withTimestamp: timestamp, threadId: threadId, author: address, transaction: trans)
        }
        return message
    }
    
    func ownerActionName(_ address: SignalServiceAddress?, trans: SDSAnyReadTransaction) -> String? {
        guard let address = address else {
            return nil
        }
        let string = contactsManager.displayName(for: address, transaction: trans)
        return string
    }
    
    private var ownerActionAddress: SignalServiceAddress? {
        guard let userInfo = infoMessageUserInfo else {
            return nil
        }
        
        guard let userAction = userInfo[.pinMessageUserAction] as? [String: Any],
              let phoneNumber = userAction["phoneNumber"] as? String,
              let uuid = userAction["uuid"] as? String else {
            return nil
        }
        
        return SignalServiceAddress(uuidString: uuid, phoneNumber: phoneNumber)
    }
    
    
    func authorMessageName(trans: SDSAnyReadTransaction) -> String? {
        guard let address = authorMessageAddress else {
            return nil
        }
        let string = contactsManager.displayName(for: address)
        return string
    }
    
    private var authorMessageAddress: SignalServiceAddress? {
        guard let userInfo = infoMessageUserInfo else {
            return nil
        }
        
        guard let userAction = userInfo[.pinMessageAuthor] as? [String: Any],
              let phoneNumber = userAction["phoneNumber"] as? String,
              let uuid = userAction["uuid"] as? String else {
            return nil
        }
        
        return SignalServiceAddress(uuidString: uuid, phoneNumber: phoneNumber)
    }
    
    var pinMessageAction: String {
        guard let userInfo = infoMessageUserInfo,
              let action = userInfo[.pinMessageAction] as? String else {
            return ""
        }
        return action
    }
    
    var pinMessageSequence: Int {
        guard let userInfo = infoMessageUserInfo,
              let sequence = userInfo[.pinMessageSequence] as? NSNumber else {
            return 0
        }
        return sequence.intValue
    }
    
}

public enum PinMessageAction: String {
    case pin
    case unpin
    case reorder
}

//MARK: GroupCall
@objc public
extension TSInfoMessage {
    func changeGroupCallType(_ callType: RPRecentCallType) {
        guard var userInfo = infoMessageUserInfo else {
            return
        }
        let key = InfoMessageUserInfoKey(rawValue: "callType")
        userInfo[key] = NSNumber(value: callType.rawValue)
        databaseStorage.write { trans in
            self.anyUpdateInfoMessage(transaction: trans) { infoMsg in
                infoMsg.change(userInfo)
            }
        }
    }
    
    var groupCallType:RPRecentCallType {
        let key = InfoMessageUserInfoKey(rawValue: "callType")
        guard messageType == .groupCall,
              let userInfo = infoMessageUserInfo,
              let value = userInfo[key] as? NSNumber,
              let callType = RPRecentCallType(rawValue: value.uintValue) else {
            return .incomingBusyElsewhere
        }
        return callType
    }
}

//MARK: WallPaper
@objc public
extension TSInfoMessage {
    private var updateWallPaperOwnerActionAddress: SignalServiceAddress? {
        guard let userInfo = infoMessageUserInfo else {
            return nil
        }
        
        let key = InfoMessageUserInfoKey(rawValue: "userAction")
        guard let userAction = userInfo[key] as? [String: Any],
              let phoneNumber = userAction["phoneNumber"] as? String,
              let uuid = userAction["uuid"] as? String else {
            return nil
        }
        
        return SignalServiceAddress(uuidString: uuid, phoneNumber: phoneNumber)
    }
    
    func updateWallPaperPreviewText(trans: SDSAnyReadTransaction) -> String {
        guard let ownerAction = updateWallPaperOwnerActionAddress,
              let localAddress = TSAccountManager.sharedInstance().localAddress else {
            return ""
        }
        var userName = ""
        
        if ownerAction == localAddress {
            userName = NSLocalizedString("GROUP_MEMBER_LOCAL_USER",
                                                 comment: "Label indicating the local user.")
        }else {
            userName = ownerActionName(ownerAction, trans: trans) ?? ""
        }
        
        let actionKey = InfoMessageUserInfoKey(rawValue: "action")
        var action = ""
        if let userInfo = infoMessageUserInfo,
              let val = userInfo[actionKey] as? String {
            action = val
        }
        
        if action == "set" {
            action = NSLocalizedString("CHANGED_CHAT_BACKGROUND",
                                       comment: "")
            return "\(userName) \(action)"
        }
        else if action == "remove" {
            action = NSLocalizedString("REMOVED_CHAT_BACKGROUND",
                                       comment: "")
            return "\(userName) \(action)"
        }
                
        return "\(userName) \(action) \(NSLocalizedString("MESSAGE_METADATA_VIEW_TITLE", comment: "").lowercased())"
    }
}
