//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit
import CallKit
import PushKit
import JitsiMeetSDK

var CALLKIT_MANAGER:FLManuallyCallKitManager {
    return FLManuallyCallKitManager.shared
}

private let JITSI_INTERN_GROUP_CALL = "yoush_group:"
private let JITSI_INTERN_CALL = "yoush:"

@objc
class FLManuallyCallKitManager: NSObject {
    @objc public static let shared = FLManuallyCallKitManager()
    private let audioActivity = AudioActivity(audioDescription: "[FLManuallyCallKitManager]", behavior: .call)
    var provider: CXProvider!
    var callController:CXCallController!
    
    func config() {
        enableJitsiCallKit = false
        if let calkitAdaptee = CALL_SERVIVE.callUIAdapter?.adaptee as? CallKitCallUIAdaptee {
            provider = calkitAdaptee.provider
            provider.setDelegate(self, queue: nil)
            callController = calkitAdaptee.callManager.callController
            RTCAudioSession.sharedInstance().add(self)
        }else {
            let configuration = buildProviderConfiguration(useSystemCallLog: true)
            provider = CXProvider(configuration: configuration)
        }
        if callController == nil  {
            callController = CXCallController()
        }
        RTCAudioSession.sharedInstance().useManualAudio = true
    }
    
    var enableJitsiCallKit:Bool {
        get {
            return JMCallKitProxy.enabled
        }
        set {
            JMCallKitProxy.enabled = newValue
        }
    }
    func startOutgogingCall(_ call: SignalCall) {
        Environment.shared.audioSession.startAudioActivity(call.audioActivity)
        CALL_SERVIVE.isRTCAudioSessionEnabled = true
        
        CALL_SERVIVE.logCallFlow("\(self.classNameString): startOutgogingCall", content: call.localId.uuidString)
        
        let handle: CXHandle
        let type: CXHandle.HandleType
        let value: String
        type = .generic
        value = call.callerName
        handle = CXHandle(type: type, value: value)
        
        let startCallAction = CXStartCallAction(call: call.localId, handle: handle)

        startCallAction.isVideo = call.hasLocalVideo

        let transaction = CXTransaction()
        transaction.addAction(startCallAction)
        
        request(transaction) { error in
            if let err = error {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): startOutgogingCall fail", content: err)
            }else {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): startOutgogingCall success")
            }
        }
        
    }
    
    func handleIncomingCallFromPushKit(_ payload: PKPushPayload, completion: ((Error?) -> Void)?) {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            self.enableJitsiCallKit = false
        }
        if let callDataDict = payload.dictionaryPayload["call-data"] as? NSDictionary {
            SSKEnvironment.shared.messageFetcherJob.run()
            
            CALL_SERVIVE.isRTCAudioSessionEnabled = true
            
            CALL_SERVIVE.logCallFlow("\(self.classNameString): didReceiveIncomingPushWith", content: callDataDict)
            
            let callerPhoneNumber = callDataDict["callerPhoneNumber"] as? String
            let groupName = callDataDict["groupName"] as? String
            let groupId = (callDataDict["groupId"] as? String) ?? ""
            let title = (groupName ?? callerPhoneNumber) ?? NSLocalizedString("CALLKIT_ANONYMOUS_CONTACT_NAME", comment: "The generic name used for calls if CallKit privacy is enabled")
            //Create a signalCall from this
            
            let callKitId = CallKitCallManager.kAnonymousCallHandlePrefix + "\(Date().timeIntervalSince1970)"
            let callId = UUID(uuidString: callKitId) ?? UUID()

            let hasCallInProgress = CALL_SERVIVE.hasCallInProgress
            
            var audioOnly = true
            if callDataDict["audioOnly"] != nil {
                if let boolVal = callDataDict["audioOnly"] as? Bool {
                    audioOnly = boolVal
                }
                else if let strVal = callDataDict["audioOnly"] as? String {
                    audioOnly = strVal.lowercased() == "true"
                }
            }
            
            var signalCall:SignalCall?
            var subject = title
            if let thread = CALL_SERVIVE.findThreadFromJitsiRoom(groupId) {
                DATABASE_STORE.uiRead { trans in
                    subject = Environment.shared.contactsManager.displayName(for: thread, transaction: trans)
                }
                if let groupThread = thread as? TSGroupThread {
                    signalCall = JitsiGroupCall.instance(groupThread, direction: .incoming, localId: callId, room: groupId, subject: subject, audioOnly: audioOnly, state: .localRinging, callId: Date.ows_millisecondTimestamp())
                }
                else if let contactThread = thread as? TSContactThread {
                    signalCall = SignalCall.instance(contactThread, direction: .incoming, localId: callId, room: groupId, subject: subject, audioOnly: audioOnly, state: .localRinging, callId: Date.ows_millisecondTimestamp())
                }
                //Place this call if hasCallInProgress == false
                if hasCallInProgress == false,
                   signalCall != nil {
                    CALL_SERVIVE.placeCall(signalCall!)
                }
            }
            
            let handle = handleIntern(signalCall)
            reportNewIncomingCall(callId, handle: handle, displayname: title, hasVideo: audioOnly == false) { error in
                completion?(error)
                if hasCallInProgress ||
                    signalCall == nil {
                    self.reportCall(callId, endedAt: nil, reason: .failed)
                    signalCall?.updateState(.localHangup)
                }
            }
        }else {
            let callKitId = CallKitCallManager.kAnonymousCallHandlePrefix + "\(Date().timeIntervalSince1970)"
            let callId =  UUID(uuidString: callKitId) ?? UUID()
            reportNewIncomingCall(callId, handle: "Yoush", displayname: "Unknown", hasVideo: false) { error in
                completion?(error)
                self.reportCall(callId, endedAt: nil, reason: .failed)
            }
        }
    }
    
    func reportNewIncomingCall(_ call: SignalCall, completion: ((Error?) -> Void)?) {
        Environment.shared.audioSession.startAudioActivity(call.audioActivity)
        let handle = handleIntern(call)
        
        // Construct a CXCallUpdate describing the incoming call, including the caller.
        
        reportNewIncomingCall(call.localId, handle: handle, displayname: call.callerName, hasVideo: call.audioOnly == false, completion: completion)
    }
    
    func handleMissCall(_ callId: UUID, reason: CXCallEndedReason = .failed) {
        self.reportCall(callId, endedAt: nil, reason: reason)
    }
    
    func endCall(_ call: SignalCall? = nil, callUUID:UUID, completion: ((Error?) -> Void)? = nil) {
        CALL_SERVIVE.logCallFlow("\(self.classNameString): requesting end call", content: callUUID.uuidString)
        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction()
        transaction.addAction(endCallAction)
        
        callController.request(transaction) { error in
            if error != nil {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): requesting end call fail with error \(error!)", content: callUUID.uuidString)
                self.reportCall(callUUID, endedAt: nil, reason: .failed)
                CALL_SERVIVE.terminateCall(call)
            }else {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): requesting end call success", content: callUUID.uuidString)
            }
            
            //This task should be in main thread
            DispatchQueue.main.async {
                completion?(error)
                call?.updateState(.localHangup)
            }
        }
//        endCallAction.fulfill()
    }
    
    func handleIntern(_ call: SignalCall?) -> String {
        var handle = ""
        let currentThread = call?.currentThread
        if let groupThread = currentThread as? TSGroupThread {
            handle = JITSI_INTERN_GROUP_CALL + groupThread.uniqueId
        }
        
        else if let contactThread = currentThread as? TSContactThread  {
            var str = ""
            if let phoneNumber = contactThread.contactAddress.phoneNumber,
               !phoneNumber.isEmpty {
                str = "\(phoneNumber)"
            }else {
                str = "\(contactThread.contactAddress.phoneNumber ?? "")_yoush_\(contactThread.contactAddress.uuid?.uuidString ?? "")"
            }
            handle = JITSI_INTERN_CALL + str
        }
        return handle
    }
    
    
    @objc
    public func startCallFromIntern(_ handle: String, isVideoCall: Bool) {
        //If has group call prefix
        if handle.hasPrefix(JITSI_INTERN_GROUP_CALL) {
            let groupId = handle.replacingOccurrences(of: JITSI_INTERN_GROUP_CALL, with: "")
            var groupThread:TSGroupThread?
            DATABASE_STORE.uiRead { trans in
                groupThread = TSThread.anyFetch(uniqueId: groupId, transaction: trans) as? TSGroupThread
            }
            if let thread = groupThread {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): startCallFromIntern: \(thread.groupNameOrDefault)")
                CALL_SERVIVE.startCall(thread, audioOnly: isVideoCall == false, fromVC: nil)
            }
        }
        else if handle.hasPrefix(JITSI_INTERN_CALL) {
            //If has 1-1 call prefix
            let str = handle.replacingOccurrences(of: JITSI_INTERN_CALL, with: "")
            var contactThread:TSContactThread?
            if str.contains("_yoush_") {
                let arr = str.components(separatedBy: "_yoush_")
                //combine contact thread with [uuid]_yoush_[phoneNumber]
                if arr.count == 2 {
                    let phoneNumber = arr[0]
                    let uuid = arr[1]
                    let address = SignalServiceAddress(uuidString: uuid, phoneNumber: phoneNumber)
                    let finder = AnyContactThreadFinder()
                    DATABASE_STORE.uiRead { trans in
                        contactThread = finder.contactThread(for: address, transaction: trans)
                    }
                }
            }else {
                let phoneNumber = str
                let address = SignalServiceAddress(uuidString: nil, phoneNumber: phoneNumber)
                let finder = AnyContactThreadFinder()
                DATABASE_STORE.uiRead { trans in
                    contactThread = finder.contactThread(for: address, transaction: trans)
                }
            }
            if let thread = contactThread {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): startCallFromIntern: \(thread.contactPhoneNumber ?? "")")
                CALL_SERVIVE.startCall(thread, audioOnly: isVideoCall == false, fromVC: nil)
            }
        }
    }
}

extension FLManuallyCallKitManager {
    func hasActiveCall(_ callUUID:String) -> Bool {
        for call in CALL_SERVIVE.calls {
            if call.localId.uuidString == callUUID {
                return true
            }
        }
        return false
    }
    
    func reportNewIncomingCall(_ uuid: UUID, handle: String?, displayname: String?, hasVideo: Bool, completion: ((Error?) -> Void)?) {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            self.enableJitsiCallKit = false
        }
        CALL_SERVIVE.logCallFlow("\(self.classNameString): reportNewIncomingCall", content: uuid.uuidString)
        // Construct a CXCallUpdate describing the incoming call, including the caller.
        let update = CXCallUpdate()
        update.localizedCallerName = displayname
        
        let type: CXHandle.HandleType
        let value: String
        type = .generic
        value = handle ?? ""
        update.remoteHandle = CXHandle(type: type, value: value)

        update.hasVideo = hasVideo

        disableUnsupportedFeatures(callUpdate: update)

        // Report the incoming call to the system
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            /*
             Only add incoming call to the app's list of calls if the call was allowed (i.e. there was no error)
             since calls may be "denied" for various legitimate reasons. See CXErrorCodeIncomingCallError.
             */
//            guard error == nil else {
//                Logger.error("failed to report new incoming call, error: \(error!)")
//                return
//            }
//
//            self.callManager.addCall(call)
            if let error = error {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): Error reportNewIncomingCall: \(error)")
            } else {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): reportNewIncomingCall successfully")
            }
//            self.provider.reportCall(with: uuid, updated: update)
            completion?(error)
//            if let call = CALL_SERVIVE.findCall(uuid) {
//                self.reportCallUpdate(uuid, handle: self.handleIntern(call), displayname: call.callerName, hasVideo: call.hasLocalVideo)
//            }
        }
    }
    
    func reportCallUpdate(_ uuid: UUID, handle: String?, displayname: String?, hasVideo: Bool) {
        let update = CXCallUpdate()
        update.localizedCallerName = displayname
        
        let type: CXHandle.HandleType
        let value: String
        type = .generic
        value = handle ?? ""
        update.remoteHandle = CXHandle(type: type, value: value)
        update.hasVideo = hasVideo

        disableUnsupportedFeatures(callUpdate: update)
        provider.reportCall(with: uuid, updated: update)
    }
    
    
    func reportCall(_ uuid: UUID, endedAt: Date?, reason: CXCallEndedReason) {
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
    }
    
    func reportOutgoingCall(_ uuid: UUID, startedConnectingAt: Date?) {
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: startedConnectingAt)
    }
    
    func reportOutgoingCall(_ uuid: UUID, connectedAt: Date?) {
        provider.reportOutgoingCall(with: uuid, connectedAt: connectedAt)
        if let call = CALL_SERVIVE.findCall(uuid) {
            reportCallUpdate(uuid, handle: handleIntern(call), displayname: call.callerName, hasVideo: call.audioOnly == false)
        }
    }
    
    func request(_ trans: CXTransaction, completion: ((Error?) -> Void)?) {
        callController.request(trans) { error in
            if let error = error {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): Error requesting transaction: \(error)")
            } else {
                CALL_SERVIVE.logCallFlow("\(self.classNameString): Requested transaction successfully")
            }
            completion?(error)
        }
    }
    
    // The app's provider configuration, representing its CallKit capabilities
    private func buildProviderConfiguration(useSystemCallLog: Bool) -> CXProviderConfiguration {
        let localizedName = NSLocalizedString("APPLICATION_NAME", comment: "Name of application")
        let providerConfiguration = CXProviderConfiguration(localizedName: localizedName)

        providerConfiguration.supportsVideo = true

        // Default maximumCallGroups is 2. We previously overrode this value to be 1.
        //
        // The terminology can be confusing. Even though we don't currently support "group calls"
        // *every* call is in a call group. Our call groups all just happen to be "groups" with 1
        // call in them.
        //
        // maximumCallGroups limits how many different calls CallKit can know about at one time.
        // Exceeding this limit will cause CallKit to error when reporting an additional call.
        //
        // Generally for us, the number of call groups is 1 or 0, *however* when handling a rapid
        // sequence of offers and hangups, due to the async nature of CXTransactions, there can
        // be a brief moment where the old limit of 1 caused CallKit to fail the newly reported
        // call, even though we were properly requesting hangup of the old call before reporting the
        // new incoming call.
        //
        // Specifically after 10 or so rapid fire call/hangup/call/hangup, eventually an incoming
        // call would fail to report due to CXErrorCodeRequestTransactionErrorMaximumCallGroupsReached
        //
        // ...so that's why we no longer use the non-default value of 1, which I assume was only ever
        // set to 1 out of confusion.
        // providerConfiguration.maximumCallGroups = 1

        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1

        providerConfiguration.supportedHandleTypes = [.phoneNumber, .generic]

        let iconMaskImage = UIImage(named: "0-you-sh-40")
         providerConfiguration.iconTemplateImageData = iconMaskImage?.pngData()

        // We don't set the ringtoneSound property, so that we use either the
        // default iOS ringtone OR the custom ringtone associated with this user's
        // system contact.
//        providerConfiguration.includesCallsInRecents = useSystemCallLog

        //Always ignore calls in recents
        providerConfiguration.includesCallsInRecents = false
        return providerConfiguration
    }
    
    private func disableUnsupportedFeatures(callUpdate: CXCallUpdate) {
        // Call Holding is failing to restart audio when "swapping" calls on the CallKit screen
        // until user returns to in-app call screen.
        callUpdate.supportsHolding = false

        // Not yet supported
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false

        // Is there any reason to support this?
        callUpdate.supportsDTMF = false
    }
    
    var currentCallVC: FLJitsiMeetCallVC? {
        return UIApplication.shared.frontmostViewController as? FLJitsiMeetCallVC
    }
}

extension FLManuallyCallKitManager: RTCAudioSessionDelegate {

    /** Called after the audio session failed to change the active state.
     */
    func audioSession(_ audioSession: RTCAudioSession, failedToSetActive active: Bool, error: Error) {
        CALL_SERVIVE.logCallFlow("\(self.classNameString): failedToSetActive: \(active) error: \(error)")
    }
}

extension FLManuallyCallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        AssertIsOnMainThread()
        Logger.info("")
        
        if let call = CALL_SERVIVE.currentCall {
            CALL_SERVIVE.terminateCall(call)
            reportCall(call.localId, endedAt: Date(), reason: .failed)
        }
        CALL_SERVIVE.calls.removeAll()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        AssertIsOnMainThread()
        CALL_SERVIVE.logCallFlow("\(self.classNameString): performStartCall", content: action.callUUID)
        Logger.info("CXStartCallAction")
        
        guard let call = CALL_SERVIVE.findCall(action.callUUID) else {
            CALL_SERVIVE.logCallFlow("\(self.classNameString): unable to find call", content: action.callUUID)
            return
        }
        
        action.fulfill()
        self.provider.reportOutgoingCall(with: call.localId, startedConnectingAt: nil)
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            self.enableJitsiCallKit = false
        }
        CALL_SERVIVE.isRTCAudioSessionEnabled = true
        
        CALL_SERVIVE.logCallFlow("\(self.classNameString): performAnswerCall: \(action.callUUID)")
        
        guard let call = CALL_SERVIVE.findCall(action.callUUID) else {
            CALL_SERVIVE.logCallFlow("\(self.classNameString): performAnswerCall can not find call: \(action.callUUID)")
            action.fail()
            return
        }
        if Environment.shared.audioSession.containsAudioActivity(call.audioActivity) == false {
            Environment.shared.audioSession.startAudioActivity(call.audioActivity)
        }
        call.updateState(.connected)

        CALL_SERVIVE.showJitsiCall(call, fromVC: UIApplication.shared.frontmostViewController, animated: true)
        
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            self.enableJitsiCallKit = false
        }
        CALL_SERVIVE.logCallFlow("\(self.classNameString): performEndCall: \(action.callUUID)")
        guard let call = CALL_SERVIVE.findCall(action.callUUID) else {
            if let call = CALL_SERVIVE.currentCall {
                CALL_SERVIVE.terminateCall(call)
                reportCall(call.localId, endedAt: Date(), reason: .failed)
            }
            CALL_SERVIVE.logCallFlow("\(self.classNameString): performEndCall can not find call: \(action.callUUID)")
            action.fail()
            return
        }
        //Notify declined call to caller if user declien from callkit control
        if call.isGroupCall == false,
           call.state == .localRinging,
           let thread = call.currentThread {
            CALL_SERVIVE.sendEndCallMessage(thread,
                                            state: CallState.endCall.rawValue,
                                            callId: call.localId.uuidString)
        }
        
        call.updateState(.localHangup)
        
        CALL_SERVIVE.terminateCall(call)
        
        currentCallVC?.endCallFromCallKit = true
        currentCallVC?.leaveRoomManual = true
        currentCallVC?.jitsiMeetView?.leave()
        
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        AssertIsOnMainThread()
        
        // Signal to the system that the action has been successfully performed.
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        AssertIsOnMainThread()
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
        AssertIsOnMainThread()
        
        Logger.warn("unimplemented \(#function) for CXSetGroupCallAction")
        action.fail()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
//        AssertIsOnMainThread()
        
        Logger.warn("unimplemented \(#function) for CXPlayDTMFCallAction")
        action.fail()
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
//        AssertIsOnMainThread()
        
        if #available(iOS 13, *), let muteAction = action as? CXSetMutedCallAction {
            guard CALL_SERVIVE.findCall(muteAction.callUUID) != nil else {
                // When a call is over, if it was muted, CallKit "helpfully" attempts to unmute the
                // call with "CXSetMutedCallAction", presumably to help us clean up state.
                //
                // That is, it calls func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction)
                //
                // We don't need this - we have our own mechanism for coallescing audio state, so
                // we acknowledge the action, but perform a no-op.
                //
                // However, regardless of fulfilling or failing the action, the action "times out"
                // on iOS13. CallKit similarly "auto unmutes" ended calls on iOS12, but on iOS12
                // it doesn't timeout.
                //
                // Presumably this is a regression in iOS13 - so we ignore it.
                // #RADAR FB7568405
                Logger.info("ignoring timeout for CXSetMutedCallAction for ended call: \(muteAction.callUUID)")
                return
            }
        }
        
        CALL_SERVIVE.logCallFlow("\(self.classNameString): Timed out while performing: \(action)")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        AssertIsOnMainThread()

        Logger.debug("Received")

        CALL_SERVIVE.logCallFlow("\(self.classNameString): providerDidActivateAudioSession")

        if let call = CALL_SERVIVE.currentCall,
           Environment.shared.audioSession.containsAudioActivity(call.audioActivity) == false {
            Environment.shared.audioSession.startAudioActivity(call.audioActivity)
        }

        CALL_SERVIVE.isRTCAudioSessionEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        AssertIsOnMainThread()

        Logger.debug("Received")
        if let call = CALL_SERVIVE.currentCall {
            Environment.shared.audioSession.endAudioActivity(call.audioActivity)
        }
        CALL_SERVIVE.isRTCAudioSessionEnabled = false
    }
}
