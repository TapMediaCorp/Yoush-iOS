//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit
import JitsiMeetSDK
import CallKit
import WebRTC
import SwiftJWT

//https://jitsi.github.io/handbook/docs/dev-guide/mobile-feature-flags
/*
 If one to one, the tile-view should be selected by default. HOW???
 */

private let REMAINING_INTERVAL = 40//It's will end at 40s

@objc
class FLJitsiMeetCallVC: UIViewController {
    @objc public var call: SignalCall!
    @objc public var isJoinCall = false
    
    private var membersInRoom = [[String:Any]]()
    private var myInfo:[String:Any]?
    private var numberJoined = 0
    private var callWaitingTimer: Timer?
    
    var leaveRoomManual = false
    var endCallFromCallKit = false
    private var didDismissView = false
    
    private var configJitsi = false
    
    var jitsiMeetView: JitsiMeetView! {
        return (view as! JitsiMeetView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        if call.direction == .outgoing,
           isJoinCall == false {
            CALL_SERVIVE.callUIAdapter.audioService.handleRemoteRinging(call: call)
        }
        if CurrentAppContext().reportedApplicationState != .background {
            ows_askForMicrophonePermissions {[weak self]  (granted) in
                guard let self = self else { return }
                guard granted == true else {
                    Logger.warn("aborting due to missing microphone permissions.")
                    self.ows_showNoMicrophonePermissionActionSheet2 { (_) in
                        self.leaveRoomManual = true
                        self.handleBeforeLeaveRoom()
                        self.didDismissView = true
                        self.dismiss(animated: true, completion: nil)
                    }
                    return
                }
               self.initJitsiView("#config.disableAEC=false&config.p2p.enabled=false")
                // self.initJitsiView("#config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.disableHPF=true&config.stereo=true&config.p2p.enabled=false")
            }
        }else {
           self.initJitsiView("#config.disableAEC=false&config.p2p.enabled=false")
            // self.initJitsiView("#config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.disableHPF=true&config.stereo=true&config.p2p.enabled=false")
        }
    }
    
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        guard configJitsi == false else {
//            return
//        }
//        configJitsi = true
//
//        // Do any additional setup after loading the view.
//        selectConfig { [weak self] result in
//            guard let self = self else { return }
//
//            if let config = result.value as? String {
//                self.initJitsiView(config)
//            }
//        }
//    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        callWaitingTimer?.invalidate()
        callWaitingTimer = nil
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
//            if CALLKIT_MANAGER.callController.calls.count > 0 {
//                for call in CALLKIT_MANAGER.callController.calls {
//                    CALLKIT_MANAGER.endCall(callUUID: call.uuid)
//                }
//            }
            CALL_SERVIVE.calls.removeAll()
            if CALL_SERVIVE.currentCall != nil {
                CALL_SERVIVE.terminateCall(CALL_SERVIVE.currentCall)
            }
        }
    }
}

extension FLJitsiMeetCallVC : JitsiMeetViewDelegate {
    /**
     * Called when a conference was joined.
     *
     * The `data` dictionary contains a `url` key with the conference URL.
     */
    func conferenceJoined(_ data: [AnyHashable : Any]!) {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            CALLKIT_MANAGER.enableJitsiCallKit = false
        }
        if call.direction == .outgoing {
            callWaitingTimer = WeakTimer.scheduledTimer(timeInterval: TimeInterval(REMAINING_INTERVAL),
                                                        target: self,
                                                        userInfo: nil,
                                                        repeats: true) {[weak self] _ in
                guard let self = self else { return }
                self.callWaitingTimer?.invalidate()
                self.callWaitingTimer = nil
                guard self.leaveRoomManual == false else { return }
                
                //If There is no member join in 40s => leave the room
                if self.membersInRoom.count <= 1 {
                    self.call.updateState(.localHangup)
                    //Leave the group
                    self.leaveRoomManual = true
                    
                    self.jitsiMeetView?.leave()
                    //Notify the call is ended
                    self.sendEndCallMessage()
                }
            }
            
            CALLKIT_MANAGER.reportOutgoingCall(call.localId, startedConnectingAt: Date())
        }else {
            self.call.updateState(.connected)
        }
        
        jitsiMeetView?.retrieveParticipantsInfo({ [weak self]  result in
            guard let self = self else { return }
            
            guard let result = result as? [[String: Any]] else {
                return
            }
            self.membersInRoom = result
            self.myInfo = result.first(where: {($0["isLocal"] as? Bool) == true})
            print("ParticipantsInfo:\n\(self.membersInRoom)")
            if result.count > 1 {
                if self.call.direction == .outgoing {
                    //Stop remote riging
                    CALL_SERVIVE.callUIAdapter.audioService.stopPlayingAnySounds()
                }
                    
                CALL_SERVIVE.isRTCAudioSessionEnabled = true
                if Environment.shared.audioSession.containsAudioActivity(self.call.audioActivity) == false{
                    Environment.shared.audioSession.startAudioActivity(self.call.audioActivity)
                }
                Environment.shared.audioSession.ensureAudioState()
            }
        })
    }
    
    /**
     * Called when the active conference ends, be it because of user choice or
     * because of a failure.
     *
     * The `data` dictionary contains an `error` key with the error and a `url` key
     * with the conference URL. If the conference finished gracefully no `error`
     * key will be present. The possible values for "error" are described here:
     * https://github.com/jitsi/lib-jitsi-meet/blob/master/JitsiConnectionErrors.js
     * https://github.com/jitsi/lib-jitsi-meet/blob/master/JitsiConferenceErrors.js
     */
    func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        if let error = data["error"] as? Error {
            print("conferenceTerminated with error \(error.localizedDescription)")
        }
        else {
            print("conferenceTerminated")
        }
        guard let _ = CALL_SERVIVE.currentCall else {
            if didDismissView == false {
                didDismissView = true
                dismiss(animated: true, completion: nil)
                handleBeforeLeaveRoom()
                
                if CALL_SERVIVE.callKitAvailable == false {
                    CALLKIT_MANAGER.endCall(call, callUUID: call.localId)
                }
            }
            return
        }
        handleBeforeLeaveRoom()
        
        if CALL_SERVIVE.callKitAvailable == false {
            //Terminate this call
            CALL_SERVIVE.terminateCall(call)
            CALLKIT_MANAGER.endCall(call, callUUID: call.localId)
        }
        
        if didDismissView == false {
            didDismissView = true
            dismiss(animated: true, completion: nil)
        }
    }
    
    /**
     * Called before a conference is joined.
     *
     * The `data` dictionary contains a `url` key with the conference URL.
     */
    func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            CALLKIT_MANAGER.enableJitsiCallKit = false
        }
    }
    
    /**
     * Called when a participant has joined the conference.
     *
     * The `data` dictionary contains a `participantId` key with the id of the participant that has joined.
     */
    func participantJoined(_ data: [AnyHashable : Any]!) {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            CALLKIT_MANAGER.enableJitsiCallKit = false
        }
        numberJoined += 1
        
        jitsiMeetView?.retrieveParticipantsInfo({ [weak self]  result in
            guard let self = self else { return }
            
            guard let result = result as? [[String: Any]] else {
                return
            }
            self.membersInRoom = result
            print("ParticipantsInfo:\n\(self.membersInRoom)")
            if result.count > 1 {
                self.call.updateState(.connected)
                CALL_SERVIVE.isRTCAudioSessionEnabled = true
                if Environment.shared.audioSession.containsAudioActivity(self.call.audioActivity) == false{
                    Environment.shared.audioSession.startAudioActivity(self.call.audioActivity)
                }
                Environment.shared.audioSession.ensureAudioState()
                
                if self.call.direction == .outgoing {
                    //Stop remote riging
                    CALL_SERVIVE.callUIAdapter.audioService.stopPlayingAnySounds()
                    //Report outgoing call
                    CALLKIT_MANAGER.reportOutgoingCall(self.call.localId, connectedAt: Date())
                }
            }
            
        })
    }
    
    /**
     * Called when a participant has left the conference.
     *
     * The `data` dictionary contains a `participantId` key with the id of the participant that has left.
     */
    func participantLeft(_ data: [AnyHashable : Any]!) {
        //This method called when the room has 2 member or more then a member leave room (also contains me!)
        jitsiMeetView?.retrieveParticipantsInfo({ [weak self]  result in
            guard let self = self else { return }
            
            guard let result = result as? [[String: Any]] else {
                return
            }
            
            if (result.count > 1) {
                self.membersInRoom = result
                print("ParticipantsInfo:\n\(result)")
            }
            
            //If there is only one member in room
            if result.count == 1,
               let partcipant = result.first,
               let participantId = partcipant["participantId"] as? String {
                //If user leave room by click on end call button
                if participantId == "local" {
                    //Do nothing
                    return
                }
                if self.call.direction == .outgoing {
                    //If there is no member joined
                    if self.numberJoined == 0 {
                        //Change calltype to outgoingMissed (this means "no answer")
                        self.call.updateState(.busyElsewhere)
                        //Notify the call is ended
                        self.sendEndCallMessage()
                    }else {
                        //If all member of room left except me
                        if let myId = self.myInfo?["participantId"] as? String,
                           myId == participantId {
                            CALL_SERVIVE.logCallFlow("There is only me in room => Leave manually")
                            //Leave the group
                            self.leaveRoomManual = true
                            
                            self.jitsiMeetView?.leave()
                            if self.call.isGroupCall {
                                //Notify the call is ended
                                self.sendEndCallMessage()
                            }
                        }
                    }
                }else {
                    //If all member of room left except me
                    if let myId = self.myInfo?["participantId"] as? String,
                       myId == participantId {
                        CALL_SERVIVE.logCallFlow("There is only me in room => Leave manually")
                        //Leave the group
                        self.leaveRoomManual = true
                        
                        self.jitsiMeetView?.leave()
                        if self.call.isGroupCall {
                            //Notify the call is ended
                            self.sendEndCallMessage()
                        }
                    }
                }
            }
        })
    }
    
    func audioMutedChanged(_ data: [AnyHashable : Any]!) {
        if Environment.shared.audioSession.containsAudioActivity(self.call.audioActivity) == false{
            Environment.shared.audioSession.startAudioActivity(self.call.audioActivity)
        }
        Environment.shared.audioSession.ensureAudioState()
    }
    
    func videoMutedChanged(_ data: [AnyHashable : Any]!) {
        if Environment.shared.audioSession.containsAudioActivity(self.call.audioActivity) == false{
            Environment.shared.audioSession.startAudioActivity(self.call.audioActivity)
        }
        if let value = data["muted"] as? Int {
            //0: has video
            //4: no video
            call.hasLocalVideo = value == 0
        }
        CALL_SERVIVE.callUIAdapter.audioService.ensureProperAudioSession(call: call)
        Environment.shared.audioSession.ensureAudioState()
    }
}

fileprivate
extension FLJitsiMeetCallVC {
    func sendEndCallMessage() {
        //Notify call end to group
        if let thread = call.currentThread {
            if call.isGroupCall {
                //reset hasCallInProgress for group call
                call.updateHasCallInProgressForGroupThread(false)
            }
            CALL_SERVIVE.sendEndCallMessage(thread, state: CallState.endCall.rawValue, callId: call.localId.uuidString)
        }
    }
    
    func handleBeforeLeaveRoom() {
        if JMCallKitProxy.enabled {
            CALL_SERVIVE.logCallFlow("JMCallKitProxy enabled some place => disable it now")
            CALLKIT_MANAGER.enableJitsiCallKit = false
        }
        CALL_SERVIVE.callUIAdapter.audioService.stopPlayingAnySounds()
        
        if leaveRoomManual == false {
            if call.direction == .outgoing {
                //Change calltype to outgoingMissed (this means "no answer")
                call.updateState(.localHangup)
                
                //If no member join
                if membersInRoom.count <= 1 {
                    //Send end call message
                    sendEndCallMessage()
                }else {
                    if numberJoined == 0 {
                        sendEndCallMessage()
                    }
                }
            }
            else {
                if call.isGroupCall == false {
                    sendEndCallMessage()
                }
            }
        }
        else if call.direction == .incoming,
                call.isGroupCall == false,
                //That means user leave room before join
                myInfo == nil {
            //Notify the call is ended
            self.sendEndCallMessage()
        }
        
        if CALL_SERVIVE.callKitAvailable {
            if endCallFromCallKit == false {
                didDismissView = true
                if #available(iOS 15, *) {
                    CALLKIT_MANAGER.reportCall(call.localId, endedAt: nil, reason: .remoteEnded)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                        CALLKIT_MANAGER.endCall(self.call, callUUID: self.call.localId, completion: nil)
                        self.dismiss(animated: true, completion: nil)
                    }
                }else {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                        CALLKIT_MANAGER.endCall(self.call, callUUID: self.call.localId) { _ in
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    func selectConfig(_ completion: FLAnyBlock?) {
        var options = [String]()
        
//        #config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.disableHPF=true&config.stereo=true&config.enableLipSync=false&config.p2p.enabled=false&config.prejoinPageEnabled=false
//
        options.append("config.disableAEC=true&config.p2p.enabled=false")
        options.append("config.disableAP=true&config.disableAEC=true&config.p2p.enabled=false")
        options.append("config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.p2p.enabled=false")
        options.append("config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.p2p.enabled=false")
        options.append("config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.disableHPF=true&config.p2p.enabled=false")
        options.append("config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.disableHPF=true&config.p2p.enabled=false")
        options.append("config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.disableHPF=true&config.stereo=false&config.p2p.enabled=false")
        options.append("config.disableAP=true&config.disableAEC=true&config.disableNS=true&config.disableAGC=true&config.disableHPF=true&config.stereo=true&config.p2p.enabled=false")
        
        var actions = [ActionSheetAction]()
        for (i, obj) in options.enumerated() {
            let action = ActionSheetAction(title: "\(i + 1): \(obj)", accessibilityIdentifier: nil, style: .default) { sheetAction in
                if let idx = actions.firstIndex(of: sheetAction),
                   idx < options.count {
                    let config = "#" + options[idx]
                    completion?((config, nil))
                }
            }
            actions.append(action)
        }
        
        let actionSheet = ActionSheetController(title: "Chọn Config", message: nil)
        actions.forEach { action in
            actionSheet.addAction(action)
        }
        actionSheet.addAction(OWSActionSheets.cancelAction)

        CurrentAppContext().frontmostViewController()?.present(actionSheet, animated: true)
    }
    
    func initJitsiView(_ config: String? = nil) {
        var displayName = ""
        if let address = TSAccountManager.sharedInstance().localAddress {
            displayName = Environment.shared.contactsManager.displayName(for: address)
        }
        var nameTo = ""
        if let thread = call.currentThread {
            nameTo = Environment.shared.contactsManager.displayNameWithSneakyTransaction(thread: thread)
        }
        // Do any additional setup after loading the view.
        
        let myHeader = Header(typ: "JWT")
        
        struct MyClaims: Claims {
            let moderator: Bool
            let aud: String
            let iss: String
            let sub: String
            let room: String
            let exp: Int
        }
        
        let myClaims = MyClaims(
            moderator: true,
            aud: "jitsi",
            iss: "  ",
            sub: " ",
            room: "*",
            exp: 15100006923
        );
        
        var myJWT = JWT(header: myHeader, claims: myClaims)
        
        let privateKey = Data("  ".utf8)
        
        let jwtSigner = JWTSigner.hs256(key: privateKey)
        
        let signedJWT = try? myJWT.sign(using: jwtSigner)

        if let jitsiMeetView = self.view as? JitsiMeetView,
           let call = self.call {
            let options = JitsiMeetConferenceOptions.fromBuilder { builder in
                builder.room = call.room
//                builder.subject = call.subject
//                builder.serverURL = URL(string: "https://jitsidev.tnmedcorp.com")
                if let config = config {
                    let serverURLStr = TSConstants.jitsiMeetServerUrl + config
                    builder.serverURL = URL(string: serverURLStr)
                }else {
                    builder.serverURL = URL(string: TSConstants.jitsiMeetServerUrl)
                }
//                builder.serverURL = URL(string: TSConstants.jitsiMeetServerUrl)
                builder.setAudioOnly(false)
                builder.setVideoMuted(call.audioOnly)
                builder.setAudioMuted(false)
//                builder.welcomePageEnabled = false
                builder.token = signedJWT
                //Only availabe on Jitsi 3.6.0
//                builder.callUUID = call.localId
//                builder.callHandle = "Yoush"
                let userInfo = JitsiMeetUserInfo(displayName: displayName, andEmail: nil, andAvatar: nil)
                builder.userInfo = userInfo

                let disableFeature = ["chat.enabled", "invite.enabled", "add-people.enabled", "meeting-password.enabled", "live-streaming.enabled", "video-share.enabled", "recording.enabled","pip.enabled"]

                for feature in disableFeature {
                    builder.setFeatureFlag(feature, withBoolean: false)
                }
                builder.setFeatureFlag("name.to", withValue: nameTo)
            }
            jitsiMeetView.delegate = self
            jitsiMeetView.join(options)
            
            CALLKIT_MANAGER.enableJitsiCallKit = false
            configJitsi = true
        }
    }
}
