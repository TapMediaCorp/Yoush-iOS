//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

@objc
extension ConversationViewModel {
    //MARK: PIN MESSAGE
    @discardableResult
    func pinMessage(_ message: TSMessage) -> TSOutgoingMessage? {
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        
        guard let data = pinMessageUserInfoMessage(message, action: PinMessageAction.pin.rawValue),
              let userInfo = data["userInfo"] as? [InfoMessageUserInfoKey:Any],
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        print("PIN MESSAGE:\n \(jsonText)")
        
        var outgoingMessage:TSOutgoingMessage?
        DATABASE_STORE.write { [weak self] trans in
            guard let self = self else { return }

            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
            outgoingMessage?.customMetaData = ["silent": true]
            let infoMsg = TSInfoMessage(thread: self.thread, messageType: .pinMessage, infoMessageUserInfo: userInfo)
            infoMsg.anyInsert(transaction: trans)
        }
        return outgoingMessage
    }
    
    @discardableResult
    func unpinMessage(_ message: TSMessage) -> TSOutgoingMessage? {
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        
        guard let data = pinMessageUserInfoMessage(message, action: PinMessageAction.unpin.rawValue),
              let userInfo = data["userInfo"] as? [InfoMessageUserInfoKey:Any],
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        print("UNPIN MESSAGE:\n \(jsonText)")
        var outgoingMessage:TSOutgoingMessage?
        DATABASE_STORE.write { [weak self] trans in
            guard let self = self else { return }
            
            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
            outgoingMessage?.customMetaData = ["silent": true]
            let infoMsg = TSInfoMessage(thread: self.thread, messageType: .pinMessage, infoMessageUserInfo: userInfo)
            infoMsg.anyInsert(transaction: trans)
        }
        
        return outgoingMessage
    }
    
    @discardableResult
    func reorderPinmessages(_ reorderData: [String:Any]) -> TSOutgoingMessage? {
        var infoMessages = [TSInfoMessage]()
        DATABASE_STORE.write { trans in
            for infoMessageId in reorderData.keys {
                guard let data = reorderData[infoMessageId] as? [String: Any],
                      let infoMsg = data["infoMsg"] as? TSInfoMessage,
                      var userInfo = infoMsg.infoMessageUserInfo,
                      let sequence = data["sequence"] as? Int  else {
                    continue
                }
                userInfo[.pinMessageSequence] = sequence
                infoMessages.append(infoMsg)
                infoMsg.anyUpdateInfoMessage(transaction: trans) { infoMsg in
                    infoMsg.infoMessageUserInfo = userInfo
                }
            }
        }
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        
        guard let data = pinMessageUserInfoMessage(nil, action: PinMessageAction.reorder.rawValue, reorder: infoMessages),
              let userInfo = data["userInfo"] as? [InfoMessageUserInfoKey:Any],
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        print("REORDER MESSAGE:\n \(jsonText)")
        var outgoingMessage:TSOutgoingMessage?
        DATABASE_STORE.write { [weak self] trans in
            guard let self = self else { return }
            
            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
            outgoingMessage?.customMetaData = ["silent": true]
            let infoMsg = TSInfoMessage(thread: self.thread, messageType: .pinMessage, infoMessageUserInfo: userInfo)
            infoMsg.anyInsert(transaction: trans)
        }
        
        return outgoingMessage
    }
    //
    func orderedPinMessages(_ trans: SDSAnyReadTransaction) -> [TSInfoMessage] {
        let pinInfoMessages = TSInfoMessage.orderedPinMessages(thread.uniqueId, trans: trans)
        return pinInfoMessages
        
//        var items = [String: [TSInfoMessage]]()
//        var pinInfoMessages = [TSInfoMessage]()
//        let interactions = InteractionFinder.fetchPinInfoMessage(self.thread.uniqueId, transaction: trans)
//        for viewItem in interactions {
//            guard let infoMsg = viewItem as? TSInfoMessage,
//                  let message = infoMsg.message(trans: trans),
//                  message.wasRemotelyDeleted == false,//should check whether the message was deleted or not
//                  let messageId = infoMsg.infoMessageUserInfo?[.pinMessageId] as? String else {
//                continue
//            }
//            let action = infoMsg.pinMessageAction
//            if action == PinMessageAction.pin.rawValue ||
//                action == PinMessageAction.unpin.rawValue {
//                var pinItemsForMessage = items[messageId]
//                if pinItemsForMessage == nil {
//                    pinItemsForMessage = [TSInfoMessage]()
//                }
//                pinItemsForMessage?.append(infoMsg)
//                items[messageId] = pinItemsForMessage!
//            }
//        }
//        for pinItemsForMessage in items.values {
//            for infoMsg in pinItemsForMessage {
//                let action = infoMsg.pinMessageAction
//                if action == PinMessageAction.pin.rawValue {
//                    //The last pin action is pin
//                    pinInfoMessages.append(infoMsg)
//                    break
//                }
//                else if action == PinMessageAction.unpin.rawValue {
//                    //The last pin action is unpin
//                    break
//                }
//            }
//        }
//        pinInfoMessages.sort(by: {$0.pinMessageSequence > $1.pinMessageSequence})
//        return pinInfoMessages
    }
    
    func messageIsPin(_ message: TSMessage) -> Bool {
        var isPin = false
        DATABASE_STORE.uiRead { trans in
            let pinnedMessages = self.orderedPinMessages(trans)
            isPin = pinnedMessages.first { obj in
                guard let pinMessageId = obj.infoMessageUserInfo?[.pinMessageId] as? String else {
                    return false
                }
                return pinMessageId == message.uniqueId
            } != nil
        }
        return isPin
    }
}


fileprivate extension ConversationViewModel {
    func pinMessageUserInfoMessage(_ message: TSMessage?, action:String, reorder:[TSInfoMessage]? = nil) -> [String: Any]? {
        var userInfo = [InfoMessageUserInfoKey: Any]()
        userInfo[InfoMessageUserInfoKey(rawValue: "messageType")] = "pinMessage"
        userInfo[.pinMessageAction] = action
        if let message = message {
            userInfo[.pinMessageId] = message.uniqueId
            userInfo[.pinMessageTimestamp] = message.timestamp
            userInfo[.pinMessageGroupId] = thread.uniqueId
            if action == PinMessageAction.pin.rawValue {
                let sequence = NSDate.ows_millisecondTimeStamp()
                userInfo[.pinMessageSequence] = NSNumber(value: sequence)
            }
            var author = [String:Any]()
            if let msg = message as? TSIncomingMessage {
                author["uuid"] = msg.authorAddress.uuidString
                author["phoneNumber"] = msg.authorAddress.phoneNumber
            }else if let address = TSAccountManager.sharedInstance().localAddress {
                author["uuid"] = address.uuidString
                author["phoneNumber"] = address.phoneNumber
            }
            userInfo[.pinMessageAuthor] = author
        }
        else if let reorderInfoMessage = reorder {
            var messagesReorder = [[InfoMessageUserInfoKey: Any]()]
            for info in reorderInfoMessage {
                if var messageUserInfo = info.infoMessageUserInfo {
                    messageUserInfo.removeValue(forKey: .pinMessageGroupId)
                    messageUserInfo.removeValue(forKey: .pinMessageAction)
                    messageUserInfo.removeValue(forKey: .pinMessageUserAction)
                    if messageUserInfo.count > 0 {
                        messagesReorder.append(messageUserInfo)
                    }
                }
            }
            userInfo[.pinMessageReorder] = messagesReorder
        }
        
        if let address = TSAccountManager.sharedInstance().localAddress {
            var userAction = [String:Any]()
            userAction["uuid"] = address.uuidString
            userAction["phoneNumber"] = address.phoneNumber
            userInfo[.pinMessageUserAction] = userAction
        }

        
        do {
            let data = try JSONSerialization.data(withJSONObject: userInfo, options: .fragmentsAllowed)
            if let jsonText = String(data: data, encoding: .utf8) {
                return ["userInfo": userInfo,
                        "jsonText": jsonText]
            }
        } catch  {
            print("HANDLE EXCEPTION HERE")
        }
        return nil
    }
}

