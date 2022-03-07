//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

//dialing, endCall, busy

private let YOUSH_GROUP_PREFIX  = "yoush___textsecure_group__" //(groupThreadPrefix of Android)

public class JitsiGroupCall: SignalCall {
    class func instance(_ thread:TSGroupThread,
                        direction: CallDirection,
                        localId:UUID,
                        room:String,
                        subject: String,
                        audioOnly:Bool,
                        state: CallState,
                        callId: UInt64) -> JitsiGroupCall {
        let call = JitsiGroupCall(direction: direction, localId: localId, state: .dialing, remoteAddress: thread.recipientAddresses[0], sentAtTimestamp: Date.ows_millisecondTimestamp())
        call.callId = callId
        call.hasLocalVideo = audioOnly == false
        call.room = room
        call.subject = subject
        call.audioOnly = audioOnly
        call.state = state
        call.groupThread = thread
        
        return call
    }
    
    override public var isGroupCall: Bool {
        return true
    }
}

extension SignalCall {
    class func instance(_ thread:TSContactThread,
                        direction: CallDirection,
                        localId:UUID,
                        room:String,
                        subject: String,
                        audioOnly:Bool,
                        state: CallState,
                        callId: UInt64) -> SignalCall {
        let call = SignalCall(direction: direction, localId: localId, state: .dialing, remoteAddress: thread.recipientAddresses[0], sentAtTimestamp: Date.ows_millisecondTimestamp())
        call.callId = callId
        call.hasLocalVideo = audioOnly == false
        call.room = room
        call.subject = subject
        call.audioOnly = audioOnly
        call.state = state
        call.thread = thread
        
        return call
    }
    
    //theCallIsEnd: The flag presents that the jitsi room is end (closed)
    func updateState(_ state: CallState, theCallIsEnd:Bool = false) {
        if direction == .incoming {
            if callRecord == nil {
                CALL_SERVIVE.updateCallRecordType(self, type: .incomingMissed)
            }
            if self.state == .localRinging {
                if state == .localHangup {
                    CALL_SERVIVE.updateCallRecordType(self, type: .incomingMissed)
                    //Notify
                    AppEnvironment.shared.notificationPresenter.presentMissedCall(self, callerName: callerName)
                }
                else if state == .connected {
                    CALL_SERVIVE.updateCallRecordType(self, type: .incoming)
                }
            }
        }
        else {
            if callRecord == nil {
                CALL_SERVIVE.updateCallRecordType(self, type: .outgoingIncomplete)
            }
            if self.state == .dialing {
                if state == .localHangup ||
                    state == .busyElsewhere {
                    CALL_SERVIVE.updateCallRecordType(self, type: .outgoingMissed)
                }
                else if state == .connected {
                    CALL_SERVIVE.updateCallRecordType(self, type: .outgoing)
                }
            }
        }
        self.state = state
        CALL_SERVIVE.callUIAdapter.audioService.ensureProperAudioSession(call: self)
    }
    
    func updateHasCallInProgressForGroupThread(_ hasCallInProgress:Bool) {
        guard let thread = currentThread as? TSGroupThread else {
            return
        }
        thread.updateHasCallInProgressForGroupThread(hasCallInProgress, callId: localId.uuidString)
    }
}
@objc

extension CallService {
    @discardableResult
    func createOutgoingCall(_ thread: TSThread, data: [String:Any]) -> SignalCall? {
        guard let room = data["room"] as? String,
              let subject = data["subject"] as? String,
              let callId = data["callId"] as? String else {
            return nil
        }
        let callUUID = UUID(uuidString: callId) ?? UUID()
        let audioOnly = (data["audioOnly"] as? Bool) ?? true
        
        //1. Create tempory signal call
        var signalCall:SignalCall!
        if let groupThread = thread as? TSGroupThread {
            signalCall = JitsiGroupCall.instance(groupThread, direction: .outgoing, localId: callUUID, room: room, subject: subject, audioOnly: audioOnly, state: .dialing, callId: Date.ows_millisecondTimestamp())
        }
        else if let contactThread = thread as? TSContactThread {
            signalCall = SignalCall.instance(contactThread, direction: .outgoing, localId: callUUID, room: room, subject: subject, audioOnly: audioOnly, state: .dialing, callId: Date.ows_millisecondTimestamp())
        }
        if let call = signalCall {
            //Insert to calls
            placeCall(call)
            
            CALLKIT_MANAGER.startOutgogingCall(call)
        }
        return signalCall
    }
    
    func handleIncomingJitsiGroupCallMessage(_ thread:TSThread, data: [String: Any]) {
        guard let _ = data["room"] as? String,
              let _ = data["subject"] as? String,
              let stateString = data["state"] as? String,
              let _ = CallState(rawValue: stateString) else {
            return
        }
        //Append to callInfos
        callInfos.append(data)
        
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 0.5) {
            var shouldProcessNow = false
            DATABASE_STORE.read { trans in
                if SSKEnvironment.shared.batchMessageProcessor.hasPendingJobs(with: trans) == false {
                    shouldProcessNow = true
                }
            }
            //When all operations were finished
            if shouldProcessNow {
                self.logCallFlow("Process Incoming Call Message", content: data)
                //Group by callId
                var data = [String:Any]()
                for obj in self.callInfos {
                    guard let obj = obj as? [String:Any],
                          let callId = obj["callId"] as? String else {
//                        self.logCallFlow("Missing data with call Info", content: obj)
                        continue
                    }
                    var calls = data[callId] as? [Any]
                    if calls == nil {
                        calls = [Any]()
                    }
                    calls?.append(obj)
                    data[callId] = calls!
                }
                
                //This task should be in main thread
                DispatchQueue.main.async {
                    //reset callInfos
                    self.callInfos.removeAll()
                    
                    if data.count > 0 {
                        if data.count == 1 {
                            let callInfo = data.values.first as! [Any]
                            self.processCallMessage(callInfo, forceIsMissed: self.hasCallInProgress)
                        }
                        else {
                            //                            let sortedCallIds = data.keys.sorted(by: {$0.uint64Value < $1.uint64Value})
                            let sortedCallIds = data.keys.sorted(by: {$0 < $1})
                            for i in 0...sortedCallIds.count - 1 {
                                let callId = sortedCallIds[i]
                                if let callInfo = data[callId] as? [Any] {
                                    let forceIsMissed = i < sortedCallIds.count - 1 || self.hasCallInProgress
                                    self.processCallMessage(callInfo, forceIsMissed: forceIsMissed)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@objc
extension CallService {
    @objc
    @discardableResult public func startCall(_ thread: TSThread?, audioOnly: Bool, fromVC: UIViewController?) -> Bool {
        guard let tsThread = thread else {
            return false
        }
        
        let vc = fromVC ?? UIApplication.shared.frontmostViewController
        guard let presenter = vc,
              let data = prepareCallData(tsThread, audioOnly: audioOnly),
              let call = data["signalCall"] as? SignalCall else {
            return false
        }
        if call.direction == .outgoing,
           let groupThread = call.threadForCall as? TSGroupThread {
            groupThread.updateHasCallInProgressForGroupThread(true, callId: call.localId.uuidString, delay: 2)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.showJitsiCall(call, fromVC: presenter, animated: true)
        }
        return true
    }
    
    @objc
    @discardableResult public func joinCall(_ thread: TSGroupThread?, callId:String?, audioOnly: Bool, fromVC: UIViewController?) -> Bool {
        guard let tsThread = thread else {
            return false
        }
        
        let vc = fromVC ?? UIApplication.shared.frontmostViewController
        guard let presenter = vc else {
            return false
        }
        var callData = [String:Any]()
        callData["room"] = callJitsiRoom(tsThread)
        let subject = SSKEnvironment.shared.contactsManager.displayNameWithSneakyTransaction(thread: tsThread)
        
        callData["subject"] = subject
        if let callId = callId,
           callId.count > 0 {
            callData["callId"] = callId
        }else {
            callData["callId"] = UUID().uuidString
        }
        callData["audioOnly"] = audioOnly
        guard let signalCall = createOutgoingCall(tsThread, data: callData) else {
            return false
        }
        
        if signalCall.direction == .outgoing,
           signalCall.isGroupCall {
            signalCall.updateHasCallInProgressForGroupThread(true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
            self.showJitsiCall(signalCall,
                               fromVC: presenter,
                               isJoinCall: true,
                               animated: true)
        }
        return true
    }
    
    ///Check a jitsi room exists or not: 200 -> exists, 404: not exist
    func checkCallInProgress(_ groupThread: TSGroupThread, completion: ((_ inProgress: Bool) -> Void)?) {
        let session = OWSSignalService.sharedInstance().cdnSessionManager(forCdnNumber: 0)
        
        var requestError: NSError?
        let urlString = TSConstants.jitsiMeetServerUrl + "/room-size"
        var params = [String:Any]()
        params["room"] = callJitsiRoom(groupThread)
        let request = session.requestSerializer.request(withMethod: "GET",
                                                        urlString: urlString,
                                                        parameters: params,
                                                        error: &requestError)
        if let _ = requestError {
            completion?(false)
            return
        }
        
        session.dataTask(with: request as URLRequest, uploadProgress: nil, downloadProgress: nil) { response, url, error in
            let hasCallInProgress = error == nil
            groupThread.updateHasCallInProgressForGroupThread(hasCallInProgress)
            completion?(error == nil)
        }.resume()
    }
    
    func findThreadFromJitsiRoom(_ room: String) -> TSThread? {
        //if this is room of group
        if room.contains(YOUSH_GROUP_PREFIX) {
            var groupThread:TSGroupThread?
            //remove groupThreadPrefix
            let hexString = room.replacingOccurrences(of: YOUSH_GROUP_PREFIX, with: "")
            if let hexData = NSData(fromHexString: hexString) {
                var threadId = hexData.base64EncodedString()
                if threadId.count > 0 {
                    //Add TSGroupThreadPrefix
                    threadId = "g" + threadId
                    DATABASE_STORE.uiRead { trans in
                        groupThread = TSThread.anyFetch(uniqueId: threadId, transaction: trans) as? TSGroupThread
                    }
                }
            }
            return groupThread
        }else {
            let prefix = "yoush_"
            if let localNumber = TSAccountManager.sharedInstance().localNumber {
                var otherNumber = room.replacingOccurrences(of: prefix, with: "")
                otherNumber = otherNumber.replacingOccurrences(of: localNumber, with: "")
                otherNumber = otherNumber.replacingOccurrences(of: "_", with: "")
                var contactThread:TSContactThread?
                let finder = AnyContactThreadFinder()
                DATABASE_STORE.uiRead { trans in
                    contactThread = finder.contactThreadForPhoneNumber(otherNumber, transaction: trans)
                }
                return contactThread
            }
        }
        return nil
    }
    
    func callJitsiRoom(_ thread: TSThread) -> String {
        if let _ = thread as? TSGroupThread {
            var room = "yoush_jitsi_group_call_\(thread.uniqueId)"
            
            //Try converting uniqueId to hex string (to match with Android)
            //Remove TSGroupThreadPrefix
            let str = thread.uniqueId.substring(from: 1)
            //Try to hex string
            if let data = NSData(fromBase64String: str),
               data.length == 16 {
                let array = [UInt8](data)
                
                //Hex this data
                let hex = StringHex.byteArrayToHexString(array)
                
                //add groupThreadPrefix
                if hex.count > 0 {
                    room = "\(YOUSH_GROUP_PREFIX)\(hex)"
                }
            }
            
            return room
        }
        else if let contactThread = thread as? TSContactThread,
                let contactNumber = contactThread.contactAddress.phoneNumber,
                let localNumber = TSAccountManager.sharedInstance().localNumber {
            let numbers = [contactNumber, localNumber].sorted(by: {$0.compare($1, options: .numeric) == .orderedAscending})
            let str = numbers.joined(separator: "_")
            let roomId = "yoush_\(str)"
            return roomId
        }
        return "Yoush_Jitsi_Call_\(thread.uniqueId)"
    }
    
    func showJitsiCall(_ signalCall: SignalCall,
                       fromVC: UIViewController?,
                       isJoinCall:Bool = false,
                       animated:Bool) {
        guard let fromVC = fromVC else {
            return
        }
        logCallFlow("Show Jitsi Call");
        if signalCall.direction == .outgoing {
            print("OUTGOING CALL: \(signalCall.callerName)")
        }else {
            print("INCOMING CALL: \(signalCall.callerName)")
        }
        
        let groupCallVC = FLJitsiMeetCallVC.instance()
        groupCallVC.call = signalCall
        groupCallVC.isJoinCall = isJoinCall
        
        if let presentedViewController = fromVC.presentedViewController {
            presentedViewController.dismiss(animated: false) {
                fromVC.presentFullScreen(groupCallVC, animated: animated)
            }
        } else {
            fromVC.presentFullScreen(groupCallVC, animated: animated)
        }
    }
    
    func callUserInfoMessage(_ thread:TSThread, state:String, callId:String, audioOnly: Bool) -> [String: Any]? {
        var userInfo = [String: Any]()
        userInfo["room"] = callJitsiRoom(thread)
        let subject = SSKEnvironment.shared.contactsManager.displayNameWithSneakyTransaction(thread: thread)
        userInfo["subject"] = subject
        
        if let _ = thread as? TSGroupThread {
            userInfo["messageType"] = "groupCall"
        }else {
            userInfo["messageType"] = "call"
        }
        userInfo["state"] = state
        userInfo["audioOnly"] = audioOnly
        userInfo["callId"] = callId
        if let address = TSAccountManager.sharedInstance().localAddress {
            var userAction = [String:Any]()
            userAction["uuid"] = address.uuidString
            userAction["phoneNumber"] = address.phoneNumber
            userInfo["caller"] = userAction
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
    
    var callKitAvailable:Bool {
        if let _ = self.callUIAdapter?.adaptee as? CallKitCallUIAdaptee {
            return true
        }
        return false
    }
    
    func sendEndCallMessage(_ thread:TSThread, state: String, callId: String) {
        if let data = callUserInfoMessage(thread, state: state, callId: callId, audioOnly: true),
           let jsonText = data["jsonText"] as? String {
            logCallFlow("Send end call message", content: jsonText)
            DATABASE_STORE.write { trans in
                let outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: thread, groupMetaMessage: .pinMessage, transaction: trans)
                //add some meta data
                var customMetaData = [String:Any]()
                customMetaData["isCallMessage"] = false
                customMetaData["jitsiRoom"] = self.callJitsiRoom(thread)
                customMetaData["silent"] = true
                outgoingMessage.customMetaData = customMetaData
            }
        }
    }
    
    func prepareCallData(_ thread: TSThread, audioOnly:Bool) -> [String:Any]? {
        //1: Create json data
        let callId = UUID()
        guard let data = callUserInfoMessage(thread, state: CallState.dialing.rawValue, callId: callId.uuidString, audioOnly: audioOnly),
              var userInfo = data["userInfo"] as? [String:Any],
              let room = userInfo["room"] as? String,
              let jsonText = data["jsonText"] as? String else {
            return nil
        }
        
        //Create outgoing message
        guard let outgoingCallMsg = sendCallMessage(thread, data: data) else {
            return nil
        }
        
        //Create info message
        userInfo["callType"] = NSNumber(value: RPRecentCallType.outgoingIncomplete.rawValue)
//        DATABASE_STORE.write {
//            infoMsg.anyInsert(transaction: $0)
//        }
        var callData = [String:Any]()
        callData["room"] = room
        let subject = SSKEnvironment.shared.contactsManager.displayNameWithSneakyTransaction(thread: thread)
        
        callData["subject"] = subject
        callData["callId"] = callId.uuidString
        callData["audioOnly"] = audioOnly
        guard let signalCall = createOutgoingCall(thread, data: callData) else {
            return nil
        }
        print("CALL MESSAGE:\n \(jsonText)")
        
        var result = [String:Any]()
        result["outgoingMsg"] = outgoingCallMsg
        result["signalCall"] = signalCall
        return result
    }
    
    func sendCallMessage(_ thread:TSThread, data:[String:Any]) -> TSOutgoingMessage? {
        ThreadUtil.addToProfileWhitelistIfEmptyOrPendingRequestWithSneakyTransaction(thread: thread)
        
        guard let jsonText = data["jsonText"] as? String else {
            return nil
        }
        
        var outgoingMessage:TSOutgoingMessage?
        DATABASE_STORE.write { trans in
            outgoingMessage = ThreadUtil.enqueueMessage(withText: jsonText, thread: thread, groupMetaMessage: .pinMessage, transaction: trans)
        }
        //add some meta data
        var customMetaData = [String:Any]()
        customMetaData["isCallMessage"] = true
        customMetaData["jitsiRoom"] = callJitsiRoom(thread)
        if let userInfo = data["userInfo"] as? [String:Any],
           let audioOnly = userInfo["audioOnly"] as? Bool {
            customMetaData["audioOnly"] = audioOnly
        }else {
            customMetaData["audioOnly"] = true
        }
        outgoingMessage?.customMetaData = customMetaData
        return outgoingMessage
    }
    
    func logCallFlow(_ title: String, content: Any? = nil) {
        print("************[JITSI CALL FLOW] \(title)************")
        if content != nil {
            print("\(content!)")
        }
    }
}

fileprivate
extension CallService {
    /*
     Incoming Call
     - incomingMissed: an missing call
     - incoming: Answered call
     
     Outgoing Call
     - outgoingIncomplete: No answer
     - outgoing: Answered call
     - outgoingMissed?
     */

    func updateCallRecordType(_ call:SignalCall, type: RPRecentCallType) {
        guard let thread = call.currentThread else {
            return
        }
        var currentCallRecord = call.callRecord
        
        /*
         Debug
        if call.direction == .outgoing {
            if currentCallRecord != nil {
                print("OUTGOING CALL: \(currentCallRecord!.callType) => \(type)")
            }else {
                print("OUTGOING CALL: \(type)")
            }
        }else {
            if currentCallRecord != nil {
                print("INCOMING CALL: \(currentCallRecord!.callType) => \(type)")
            }else {
                print("INCOMING CALL: \(type)")
            }
        }
         */
        if currentCallRecord == nil {
            currentCallRecord = TSCall(callType: type, thread: thread, sentAtTimestamp: call.sentAtTimestamp)
            DATABASE_STORE.write { trans in
                currentCallRecord?.anyInsert(transaction: trans)
            }
            call.callRecord = currentCallRecord
        }else {
            call.callRecord?.updateCallType(type)
        }
    }
    
    func processCallMessage(_ callInfo:[Any], forceIsMissed: Bool, fromPush:Bool = false) {
        if let call = currentCall,
           let data = callInfo.last as? [String: Any],
           let room = data["room"] as? String,
           call.room == room,
           let stateString = data["state"] as? String,
           let state = CallState(rawValue: stateString) {
            
            //In case the calll is active:
            //Group call: a member out then rejoin room
            //Normal call: answer from callkit then receive this message again
            if state == .dialing {
                //Safe to ignore it
                return
            }
            
            if call.direction == .outgoing {
                //If calling 1-1 then the receiver decliened the call
                if (state == .busy ||
                        state == .localHangup ||
                        state == .remoteHangup ||
                        state == .endCall),
                   call.isGroupCall == false,
                   call.state == .dialing,
                   let topVC = UIApplication.shared.frontmostViewController as? FLJitsiMeetCallVC {
                    logCallFlow("The receiver decliened => leave room", content: nil)
                    //Change to outgoingMissed
                    call.updateState(.localHangup)
                    
                    //Leave room
                    topVC.leaveRoomManual = true
                    topVC.jitsiMeetView.leave()
                    
                    //Terminate call
                    self.terminateCall(call)
                    
                    if state == .busy {
                        AppEnvironment.shared.notificationPresenter.presentReceiverBusy(call, callerName: call.callerName)
                    }
                    return
                }
            }else {
                //If the incoming call is ringing then the caller hangup this call
                if (state == .busy ||
                        state == .localHangup ||
                        state == .remoteHangup ||
                        state == .endCall) &&
                    call.state == .localRinging {
                    logCallFlow("The caller hang up => miss call", content: nil)
                    handleIncomingMissCall(call)
                    return
                }
            }
        }
        
        if hasCallInProgress {
            logCallFlow("hasCallInProgress", content: calls.first)
        }
        if callInfo.count == 1,
           forceIsMissed == false {
            guard let data = callInfo.first as? [String: Any],
                  let stateString = data["state"] as? String,
                  let state = CallState(rawValue: stateString) else {
                return
            }
            guard let thread = threadWithCallData(data) else {
                return
            }
            
            guard isValidCallMessage(thread, callData: data) else {
                return
            }
            if state == .dialing {
                handleIncomingCall(thread, callData: data)
            }
            else if state == .endCall,
                    let groupThread = thread as? TSGroupThread,
                    groupThread.hasCallInProgress == true {
                groupThread.updateHasCallInProgressForGroupThread(false)
            }
        }
        else if callInfo.count == 2 ||
                    (callInfo.count > 0 && forceIsMissed == true) {
            //It is a misscall
            guard let data = callInfo.last as? [String: Any],
                  let stateString = data["state"] as? String,
                  let room = data["room"] as? String,
                  let callId = data["callId"] as? String,
                  let state = CallState(rawValue: stateString) else {
                return
            }
            
            guard let thread = threadWithCallData(data) else {
                return
            }
            
            guard isValidCallMessage(thread, callData: data) else {
                return
            }
            
            let callUUID = UUID(uuidString: callId) ?? UUID()
            if state == .dialing,
               thread.isKind(of: TSGroupThread.self),
               hasCallInProgress {
                //We will create incoming miss call when this call ends
                return
            }
            var messageTimestamp = (data["timestamp"] as? UInt64) ?? 0
            if messageTimestamp == 0 {
                messageTimestamp = Date.ows_millisecondTimestamp()
            }
            //TODO: We should find right timestamp for it
            let callRecord = TSCall(callType: .incomingMissed, thread: thread, sentAtTimestamp: messageTimestamp)
            print("INCOMING CALL: \(RPRecentCallType.incomingMissed)")
            
            DATABASE_STORE.write { trans in
                callRecord.anyInsert(transaction: trans)
            }
            //If hasCallInProgress and there is another dialing incoming call
            if hasCallInProgress,
               state == .dialing,
               thread.isKind(of: TSContactThread.self) {
                
                if let call = currentCall,
                   call.room == room {
                    //Ignore
                    //In case user launches app from voip push
                }else {
                    sendEndCallMessage(thread, state: CallState.busy.rawValue, callId: callUUID.uuidString)
                }
            }
        }
    }
    
    func handleIncomingCall(_ thread:TSThread, callData: [String:Any]?) {
        guard var data = callData,
              let room = data["room"] as? String,
              let callId = data["callId"] as? String,
              let stateString = data["state"] as? String,
              let state = CallState(rawValue: stateString) else {
            return
        }
        var subject = ""
        let callUUID = UUID(uuidString: callId) ?? UUID()
        var audioOnly = true
        if data["audioOnly"] != nil {
            if let boolVal = data["audioOnly"] as? Bool {
                audioOnly = boolVal
            }
            else if let strVal = data["audioOnly"] as? String {
                audioOnly = strVal.lowercased() == "true"
            }
        }
        
        data["callType"] = RPRecentCallType.incomingIncomplete.rawValue
        logCallFlow("Receive Incoming Call", content: data);
        
        DATABASE_STORE.uiRead { trans in
            subject = Environment.shared.contactsManager.displayName(for: thread, transaction: trans)
        }
        
        var signalCall:SignalCall!
        if let groupThread = thread as? TSGroupThread {
            signalCall = JitsiGroupCall.instance(groupThread, direction: .incoming, localId: callUUID, room: room, subject: subject, audioOnly: audioOnly, state: state, callId: Date.ows_millisecondTimestamp())
        }
        else if let contactThread = thread as? TSContactThread {
            signalCall = SignalCall.instance(contactThread, direction: .incoming, localId: callUUID, room: room, subject: subject, audioOnly: audioOnly, state: state, callId: Date.ows_millisecondTimestamp())
        }
        
        if signalCall == nil {
            return
        }
        
        signalCall.state = .localRinging
        
        //This method will ring on device
        if self.callKitAvailable {
            CALLKIT_MANAGER.reportNewIncomingCall(signalCall.localId, handle: CALLKIT_MANAGER.handleIntern(signalCall), displayname: signalCall.callerName, hasVideo: !signalCall.audioOnly) { error in
                if let groupThread = signalCall.currentThread as? TSGroupThread {
                    groupThread.updateHasCallInProgressForGroupThread(true, callId: signalCall.localId.uuidString)
                }
                if error == nil {
                    self.placeCall(signalCall)
                }
            }
        }else {
            placeCall(signalCall)
            callUIAdapter.showCall(signalCall)
            callUIAdapter.audioService.handleLocalRinging(call: signalCall)

            if let callVC = OWSWindowManager.shared.callViewController as? CallViewController {
                callVC.actionBlock = { (action) in
                    guard let signalCall = action.obj as? SignalCall else {
                        return
                    }
                    self.callUIAdapter.audioService.stopPlayingAnySounds()
                    
                    if signalCall.direction == .incoming {
                        if action.type == "decline" {
                            //Reset audio service deletgate
                            self.callUIAdapter.audioService.delegate = nil
                            //Dismiss callVC
                            callVC.dismissImmediately(completion: nil)
                            //set callType is incomingMissed
                            signalCall.updateState(.localHangup)
                            //set hasCallInProgress for group call
                            if signalCall.isGroupCall {
                                signalCall.updateHasCallInProgressForGroupThread(true)
                            }
                            //Remove this call
                            self.terminateCall(signalCall)
                            
                            //Notify declined call to caller
                            if signalCall.isGroupCall == false,
                               let thread = signalCall.currentThread {
                                self.sendEndCallMessage(thread, state: CallState.endCall.rawValue, callId: signalCall.localId.uuidString)
                            }
                        }
                        else if action.type == "accept" {
                            //Reset audio service deletgate
                            self.callUIAdapter.audioService.delegate = nil
                            //Dismiss callVC
                            callVC.dismissImmediately(completion: nil)
                            
                            //set hasCallInProgress for group call
                            if signalCall.isGroupCall {
                                signalCall.updateHasCallInProgressForGroupThread(true)
                            }
                            
                            //show jitsi group call
                            guard let topVC = UIApplication.shared.frontmostViewControllerIgnoringAlerts else {
                                owsFailDebug("view controller unexpectedly nil")
                                return
                            }
                            self.showJitsiCall(signalCall, fromVC: topVC, animated: true)
                        }
                    }
                }
            }
        }
    }
    
    func handleIncomingMissCall(_ signalCall: SignalCall) {
        let currentState = signalCall.state
        //Change to missed call
        signalCall.updateState(.localHangup)
        
        //reset hasCallInProgress for group call
        if signalCall.isGroupCall {
            signalCall.updateHasCallInProgressForGroupThread(false)
        }
        
        //Stop ringing
        callUIAdapter.audioService.stopPlayingAnySounds()
        //Reset audio service deletgate
        callUIAdapter.audioService.delegate = nil
        //Dismiss callVC
        if let callVC = OWSWindowManager.shared.callViewController as? CallViewController,
           callVC.call.localId.uuidString == signalCall.localId.uuidString {
            callVC.dismissImmediately(completion: nil)
        }
        
        if let jitsiCallVC = UIApplication.shared.frontmostViewController as? FLJitsiMeetCallVC,
           jitsiCallVC.call.localId.uuidString == signalCall.localId.uuidString {
            jitsiCallVC.leaveRoomManual = true
            jitsiCallVC.jitsiMeetView.leave()
        }
        if callKitAvailable &&
            CALLKIT_MANAGER.hasActiveCall(signalCall.localId.uuidString) {
            if currentState == .localRinging {
                CALLKIT_MANAGER.reportCall(signalCall.localId, endedAt: nil, reason: .remoteEnded)
            }else {
                CALLKIT_MANAGER.endCall(callUUID: signalCall.localId)
            }
        }
        //Remove this call
        terminateCall(signalCall)
    }
    
    func threadWithCallData(_ callData: [String:Any]) -> TSThread? {
        guard let threadId = callData["threadId"] as? String else {
            return nil
        }
        
        var tsThread:TSThread?
        DATABASE_STORE.uiRead { trans in
            tsThread = TSThread.anyFetch(uniqueId: threadId, transaction: trans)
        }
        return tsThread
    }
    
    func isValidCallMessage(_ thread: TSThread, callData: [String:Any]) -> Bool {
        return true
//        if let messageTimestamp = callData["timestamp"] as? Int64,
//           messageTimestamp > 0 {
//            //There is issue if user receive voip for incoming call, then user opens app and receives this message call again
//            //In this case, server should not save isCallMessage
//            //For now, just ignore this call
//            var shouldIgnore = false
//            DATABASE_STORE.uiRead { trans in
//                if let interaction = thread.lastInteractionForInbox(transaction: trans) {
//                    //If the timestamp of last interaction > messageTimestamp
//                    shouldIgnore = interaction.timestamp > messageTimestamp
//                }
//            }
//            if shouldIgnore {
//                logCallFlow("Ignore call message because the messageTimestamp is old");
//                return false
//            }
//        }
//        return true
    }
}

@objc
public class StringHex: NSObject {
   private static let HEX_DIGITS : [Character] =
      [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" ]

   public static func byteArrayToHexString(_ byteArray : [UInt8]) -> String {

      var stringToReturn = ""

      for oneByte in byteArray {
         let asInt = Int(oneByte)
         stringToReturn.append(StringHex.HEX_DIGITS[asInt >> 4])
         stringToReturn.append(StringHex.HEX_DIGITS[asInt & 0x0f])
      }
      return stringToReturn
   }
}


extension TSGroupThread {
    func updateHasCallInProgressForGroupThread(_ hasCallInProgress:Bool,
                                               callId:String? = nil,
                                               delay:Double = 0.5) {
        if self.hasCallInProgress != hasCallInProgress {
            /*
             Debug
            let contactManager = Environment.shared.contactsManager
            var name = ""
            DATABASE_STORE.read { trans in
                name = contactManager?.displayName(for: thread, transaction: trans) ?? ""
            }
            if direction == .outgoing {
                print("XXXXXXXXXX: OUTGOING CALL: \(name) - \(hasCallInProgress ? "hasCallInProgress": "endCall")")
            }else {
                print("XXXXXXXXXX: INCOMING CALL: \(name) - \(hasCallInProgress ? "hasCallInProgress": "endCall")")
            }
             */
            
            self.hasCallInProgress = hasCallInProgress
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay) {
                DATABASE_STORE.write { trans in
                    self.anyUpdateGroupThread(transaction: trans) { groupThread in
                        groupThread.hasCallInProgress = hasCallInProgress
                        if hasCallInProgress == false {
                            groupThread.callIdInProgress = ""
                        } else if let callId = callId,
                                  callId.count > 0 {
                            groupThread.callIdInProgress = callId
                        }
                    }
                }
                var userInfo = [String:Any]()
                userInfo["threadId"] = self.uniqueId
                userInfo["hasCallInProgress"] = hasCallInProgress
                if self.callIdInProgress.count > 0 {
                    userInfo["callId"] = self.callIdInProgress
                }
                let notiName = Notification.Name.init(rawValue: OWSGroupCallStateDidChange)
                NTF_CENTER.post(name: notiName, object: nil, userInfo: userInfo)
            }
        }
    }
}
