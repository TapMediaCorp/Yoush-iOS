//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

//@objc
//extension ConversationViewModel {
//    func makeGroupCall(_ audioOnly:Bool) -> [String:Any]? {
//        //1: Create json data
//        let callId = UUID()
//        guard let data = AppEnvironment.shared.callService.callUserInfoMessage(thread, state: CallState.dialing.rawValue, callId: callId.uuidString, audioOnly: audioOnly),
//              var userInfo = data["userInfo"] as? [String:Any],
//              let room = userInfo["room"] as? String,
//              let jsonText = data["jsonText"] as? String else {
//            return nil
//        }
//        
//        //Create outgoing message
//        guard let outgoingCallMsg = sendCallMessage(data) else {
//            return nil
//        }
//        
//        //Create info message
//        userInfo["callType"] = NSNumber(value: RPRecentCallType.outgoingIncomplete.rawValue)
//        let infoMsg = TSInfoMessage(thread: self.thread, messageType: .groupCall, infoMessageUserInfo: userInfo)
////        DATABASE_STORE.write {
////            infoMsg.anyInsert(transaction: $0)
////        }
//        var callData = [String:Any]()
//        callData["room"] = room
//        let subject = SSKEnvironment.shared.contactsManager.displayNameWithSneakyTransaction(thread: thread)
//        
//        callData["subject"] = subject
//        callData["infoMsg"] = infoMsg
//        callData["callId"] = callId.uuidString
//        callData["audioOnly"] = audioOnly
//        guard let signalCall = AppEnvironment.shared.callService.createOutgoingCall(thread, data: callData) else {
//            return nil
//        }
//        print("CALL MESSAGE:\n \(jsonText)")
//        
//        var result = [String:Any]()
//        result["outgoingMsg"] = outgoingCallMsg
//        result["signalCall"] = signalCall
//        return result
//    }
//}
//
//@objc
//private extension ConversationViewModel {
//    func sendCallMessage(_ data:[String:Any]) -> TSOutgoingMessage? {
//        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
//        
//        guard let jsonText = data["jsonText"] as? String else {
//            return nil
//        }
//        
//        var outgoingMessage:TSOutgoingMessage?
//        DATABASE_STORE.write { [weak self] trans in
//            guard let self = self else { return }
//            
//            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: self.thread, groupMetaMessage: .pinMessage, transaction: trans)
//        }
//        //add some meta data
//        var customMetaData = [String:Any]()
//        customMetaData["isCallMessage"] = true
//        customMetaData["jitsiRoom"] = CALL_SERVIVE.callJitsiRoom(thread)
//        outgoingMessage?.customMetaData = customMetaData
//        return outgoingMessage
//    }
//}
