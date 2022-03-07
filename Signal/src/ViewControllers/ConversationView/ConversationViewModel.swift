//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

@objc
extension ConversationViewModel {
    //MARK: PIN MESSAGE
    func pinMessage(_ message: TSMessage) -> TSOutgoingMessage? {
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        guard let data = pinMessageUserInfoMessage(message, action: "pin"),
              let userInfo = data["userInfo"] as? [InfoMessageUserInfoKey:Any],
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        
        var outgoingMessage:TSOutgoingMessage?
        DATABASE_STORE.write { [weak self] trans in
            guard let self = self else { return }
            
            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
            let infoMsg = TSInfoMessage(thread: self.thread, messageType: .pinMessage, infoMessageUserInfo: userInfo)
            infoMsg.anyInsert(transaction: trans)
        }
        return outgoingMessage
    }
    
    func unpinMessage(_ message: TSMessage) -> TSOutgoingMessage? {
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        
        guard let data = pinMessageUserInfoMessage(message, action: "unpin"),
              let userInfo = data["userInfo"] as? [InfoMessageUserInfoKey:Any],
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        
        var outgoingMessage:TSOutgoingMessage?
        DATABASE_STORE.write { [weak self] trans in
            guard let self = self else { return }
            
            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
            let infoMsg = TSInfoMessage(thread: self.thread, messageType: .pinMessage, infoMessageUserInfo: userInfo)
            infoMsg.anyInsert(transaction: trans)
        }
        
        return outgoingMessage
    }
    
    func orderedPinMessages() -> [TSInfoMessage] {
        var pinInfoMessages = [TSInfoMessage]()
        var unpinInfoMessages = [TSInfoMessage]()
        for viewItem in self.viewState.viewItems.reversed() {
            guard let infoMsg = viewItem.interaction as? TSInfoMessage,
                  let action = infoMsg.infoMessageUserInfo?[.pinMessageAction] as? String,
                  let messageId = infoMsg.infoMessageUserInfo?[.pinMessageId] as? String else {
                continue
            }
            if action == "pin" {
                if pinInfoMessages.first(where: { obj in
                    guard let pinMessageId = obj.infoMessageUserInfo?[.pinMessageId] as? String else {
                        return false
                    }
                    return pinMessageId == messageId
                }) != nil {//This message is existed in pinInfoMessages
                    continue
                }
                pinInfoMessages.append(infoMsg)
            }
            else if action == "unpin" {
                unpinInfoMessages.append(infoMsg)
            }
        }
        pinInfoMessages = pinInfoMessages.filter { pinMessage in
            guard let pinMessageId = pinMessage.infoMessageUserInfo?[.pinMessageId] as? String else {
                return false
            }
            //If this message is unpin recent
            
//            return obj.timestamp > infoMsg.timestamp
            if unpinInfoMessages.first(where: { obj in
                guard let unpinMessageId = obj.infoMessageUserInfo?[.pinMessageId] as? String,
                      unpinMessageId == pinMessageId else {
                    return false
                }
                //If this message is unpin recent
                return obj.timestamp > pinMessage.timestamp
            }) !=  nil {
                return false
            }
            return true
        }
        
        //For testing
        let pinMessageIds = pinInfoMessages.map({$0.infoMessageUserInfo?[.pinMessageId] ?? ""})
        print("pinMessageIds \(pinMessageIds)")
        return pinInfoMessages
    }
    
    func messageIsPin(_ message: TSMessage) -> Bool {
        return orderedPinMessages().first { obj in
            guard let pinMessageId = obj.infoMessageUserInfo?[.pinMessageId] as? String else {
                return false
            }
            return pinMessageId == message.uniqueId
        } != nil
    }
}


fileprivate extension ConversationViewModel {
    func pinMessageUserInfoMessage(_ message: TSMessage, action:String) -> [String: Any]? {
        var userInfo = [InfoMessageUserInfoKey: Any]()
        userInfo[.pinMessageId] = message.uniqueId
        userInfo[.pinMessageTimestamp] = message.timestamp
        userInfo[.pinMessageAction] = action
        userInfo[.pinMessageGroupId] = thread.uniqueId
        userInfo[.pinMessageSequence] = NSNumber(value: 1)
        userInfo[.pinMessageUserAction] = OWSProfileManager.shared().localUserId()
        if let address = TSAccountManager.sharedInstance().localAddress {
            var userAction = [String:Any]()
            userAction["uuid"] = address.uuidString
            userAction["phoneNumber"] = address.phoneNumber
            userInfo[.pinMessageUserAction] = userAction
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

extension TSInfoMessage {
    var ownerActionName:String? {
        guard let address = ownerActionAddress else {
            return nil
        }
        var string:String?
        DATABASE_STORE.uiRead { trans in
            string = Environment.shared.contactsManager.displayName(for: address)
        }
        return string
    }
    
    var message:TSMessage? {
        guard let userInfo = infoMessageUserInfo,
              let timestamp = userInfo[.pinMessageTimestamp] as? UInt64,
              let threadId = userInfo[.pinMessageGroupId] as? String,
              let address = authorMessageAddress else {
            return nil
        }
        var message:TSMessage?
        DATABASE_STORE.uiRead { trans in
            message = InteractionFinder.findMessage(withTimestamp: timestamp, threadId: threadId, author: address, transaction: trans)
        }
        return message
    }
    
    var authorMessageName:String? {
        guard let address = authorMessageAddress else {
            return nil
        }
        var string:String?
        DATABASE_STORE.uiRead { trans in
            string = Environment.shared.contactsManager.displayName(for: address)
        }
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

}
