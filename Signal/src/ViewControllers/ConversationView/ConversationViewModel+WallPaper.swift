//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

@objc
extension ConversationViewModel {
    //MARK: PIN MESSAGE
    @discardableResult
    func setWallPaper(_ data:[String:Any]) -> TSOutgoingMessage? {
        guard let action = data["action"] as? String,
              let imageData = data["imageData"] as? Data else {
            return nil
        }
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        var imageUrl = ""
        if let val = data["imageUrl"] as? String {
            imageUrl = val
        }
        guard let data = changeWallPaperUserInfoMessage(action, imageUrl: imageUrl),
              let userInfo = data["userInfo"] as? [InfoMessageUserInfoKey:Any],
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        print("SET WALLPAPER MESSAGE:\n \(jsonText)")
        var outgoingMessage:TSOutgoingMessage?
        if imageUrl.count > 0 {
            DATABASE_STORE.write { [weak self] trans in
                guard let self = self else { return }

                outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
                outgoingMessage?.customMetaData = ["silent": true]
                let infoMsg = TSInfoMessage(thread: self.thread, messageType: .setWallPaper, infoMessageUserInfo: userInfo)
                infoMsg.anyInsert(transaction: trans)
            }
        }else {
            let dataUTI = "public.png"
            let dataSource = DataSourceValue.dataSource(with: imageData, utiType: dataUTI) //dataUTI: "public.jpeg", "png"
            let attactment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: dataUTI, imageQuality: .original)
            DATABASE_STORE.write { [weak self] trans in
                guard let self = self else { return }
                
                outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, mediaAttachments: [attactment], thread: self.thread, quotedReplyModel: nil, linkPreviewDraft: nil, groupMetaMessage:.pinMessage, transaction: trans)
                
                outgoingMessage?.customMetaData = ["silent": true]
                let infoMsg = TSInfoMessage(thread: self.thread, messageType: .setWallPaper, infoMessageUserInfo: userInfo)
                infoMsg.anyInsert(transaction: trans)
            }
        }
        
        return outgoingMessage
    }
    
    @discardableResult
    func removeWallPaper(_ data:[String:Any]) -> TSOutgoingMessage? {
        guard let action = data["action"] as? String else {
            return nil
        }
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        
        guard let data = changeWallPaperUserInfoMessage(action),
              let userInfo = data["userInfo"] as? [InfoMessageUserInfoKey:Any],
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        print("REMOVE WALLPAPER MESSAGE:\n \(jsonText)")
        var outgoingMessage:TSOutgoingMessage?
        DATABASE_STORE.write { [weak self] trans in
            guard let self = self else { return }

            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
            outgoingMessage?.customMetaData = ["silent": true]
            let infoMsg = TSInfoMessage(thread: self.thread, messageType: .setWallPaper, infoMessageUserInfo: userInfo)
            infoMsg.anyInsert(transaction: trans)
        }
        return outgoingMessage
    }
}

fileprivate extension ConversationViewModel {
    func changeWallPaperUserInfoMessage(_ action:String, imageUrl:String? = nil) -> [String: Any]? {
        var userInfo = [InfoMessageUserInfoKey: Any]()
        userInfo[InfoMessageUserInfoKey(rawValue: "messageType")] = "updateWallPaper"
        userInfo[InfoMessageUserInfoKey(rawValue: "action")] = action
        
        if let address = TSAccountManager.sharedInstance().localAddress {
            var userAction = [String:Any]()
            userAction["uuid"] = address.uuidString
            userAction["phoneNumber"] = address.phoneNumber
            userInfo[InfoMessageUserInfoKey(rawValue: "userAction")] = userAction
        }
        if let val = imageUrl,
           val.count > 0{
            userInfo[InfoMessageUserInfoKey(rawValue: "imageUrl")] = val
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
