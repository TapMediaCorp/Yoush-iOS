//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import PromiseKit
import CallKit
import SignalServiceKit
import SignalMessaging
//import WebRTC

protocol CallUIAdaptee {
    var notificationPresenter: NotificationPresenter { get }
    var callService: CallService { get }
    var hasManualRinger: Bool { get }

    func startOutgoingCall(call: SignalCall)
    func reportIncomingCall(_ call: SignalCall, callerName: String)
    func reportMissedCall(_ call: SignalCall, callerName: String)
    func answerCall(localId: UUID)
    func answerCall(_ call: SignalCall)
    func recipientAcceptedCall(_ call: SignalCall)
    func localHangupCall(localId: UUID)
    func localHangupCall(_ call: SignalCall)
    func remoteDidHangupCall(_ call: SignalCall)
    func remoteBusy(_ call: SignalCall)
    func didAnswerElsewhere(call: SignalCall)
    func didDeclineElsewhere(call: SignalCall)
    func failCall(_ call: SignalCall, error: CallError)
    func setIsMuted(call: SignalCall, isMuted: Bool)
    func setHasLocalVideo(call: SignalCall, hasLocalVideo: Bool)
    func startAndShowOutgoingCall(address: SignalServiceAddress, hasLocalVideo: Bool)
}

// Shared default implementations
extension CallUIAdaptee {
    internal func showCall(_ call: SignalCall){
//        callService.showJitsiCall(call, fromVC: UIApplication.shared.frontmostViewController, animated: true)
        
        AssertIsOnMainThread()

        let callViewController = CallViewController(call: call)
        callViewController.modalTransitionStyle = .crossDissolve

        if CallViewController.kShowCallViewOnSeparateWindow {
            OWSWindowManager.shared.startCall(callViewController)
        } else {
            guard let presentingViewController = UIApplication.shared.frontmostViewControllerIgnoringAlerts else {
                owsFailDebug("view controller unexpectedly nil")
                return
            }

            if let presentedViewController = presentingViewController.presentedViewController {
                presentedViewController.dismiss(animated: false) {
                    presentingViewController.presentFullScreen(callViewController, animated: true)
                }
            } else {
                presentingViewController.presentFullScreen(callViewController, animated: true)
            }
        }
    }

    internal func reportMissedCall(_ call: SignalCall, callerName: String) {
        AssertIsOnMainThread()

        notificationPresenter.presentMissedCall(call, callerName: callerName)
    }

    internal func startAndShowOutgoingCall(address: SignalServiceAddress, hasLocalVideo: Bool) {
        AssertIsOnMainThread()

//        guard let call = self.callService.buildOutgoingCallIfAvailable(address: address) else {
//            // @integration This is not unexpected, it could happen if Bob tries
//            // to start an outgoing call at the same moment Alice has already
//            // sent him an Offer that is being processed.
//            Logger.info("found an existing call when trying to start outgoing call: \(address)")
//            return
//        }
//
//        Logger.debug("")
//
//        startOutgoingCall(call: call)
//        call.hasLocalVideo = hasLocalVideo
//        self.showCall(call)
    }
}

/**
 * Notify the user of call related activities.
 * Driven by either a CallKit or System notifications adaptee
 */
@objc public class CallUIAdapter: NSObject, CallServiceObserver {

    private let contactsManager: OWSContactsManager
    let callService: CallService

    private var notificationPresenter: NotificationPresenter {
        return AppEnvironment.shared.notificationPresenter
    }

    var preferences: OWSPreferences {
        return Environment.shared.preferences
    }

    lazy var adaptee: CallUIAdaptee = {
        if Platform.isSimulator {
            // CallKit doesn't seem entirely supported in simulator.
            // e.g. you can't receive calls in the call screen.
            // So we use the non-CallKit call UI.
            Logger.info("choosing non-callkit adaptee for simulator.")
            return NonCallKitCallUIAdaptee(callService: callService, notificationPresenter: notificationPresenter)
        } else if CallUIAdapter.isCallkitDisabledForLocale {
            Logger.info("choosing non-callkit adaptee due to locale.")
            return NonCallKitCallUIAdaptee(callService: callService, notificationPresenter: notificationPresenter)
        } else {
            Logger.info("choosing callkit adaptee for iOS11+")
            let showNames = preferences.notificationPreviewType() != .noNameNoPreview
            let useSystemCallLog = preferences.isSystemCallLogEnabled()

            return CallKitCallUIAdaptee(callService: callService, contactsManager: contactsManager, notificationPresenter: notificationPresenter, showNamesOnCallScreen: showNames, useSystemCallLog: useSystemCallLog)
        }
    }()

    lazy var audioService: CallAudioService = {
        return CallAudioService(handleRinging: adaptee.hasManualRinger)
    }()

    public required init(callService: CallService, contactsManager: OWSContactsManager) {
        AssertIsOnMainThread()

        self.contactsManager = contactsManager
        self.callService = callService

        super.init()

        // We cannot assert singleton here, because this class gets rebuilt when the user changes relevant call settings
//        AppReadiness.runNowOrWhenAppDidBecomeReady {
//            callService.addObserverAndSyncState(observer: self)
//        }
    }

    @objc
    public static var isCallkitDisabledForLocale: Bool {
        let locale = Locale.current
        guard let regionCode = locale.regionCode else {
            if !Platform.isSimulator { owsFailDebug("Missing region code.") }
            return false
        }

        // Apple has stopped approving apps that use CallKit functionality in mainland China.
        // When the "CN" region is enabled, this check simply switches to the same pre-CallKit
        // interface that is still used by everyone on iOS 9.
        //
        // For further reference: https://forums.developer.apple.com/thread/103083
        return regionCode == "CN"
    }

    // MARK: Dependencies

    var audioSession: OWSAudioSession {
        return Environment.shared.audioSession
    }

    // MARK: 

    internal func reportIncomingCall(_ call: SignalCall, thread: TSThread) {
        AssertIsOnMainThread()

        Logger.info("remoteAddress: \(call.remoteAddress)")

        // make sure we don't terminate audio session during call
        audioSession.startAudioActivity(call.audioActivity)

        let callerName = call.callerName

        Logger.verbose("callerName: \(callerName)")

        adaptee.reportIncomingCall(call, callerName: callerName)
    }

    internal func reportMissedCall(_ call: SignalCall) {
        AssertIsOnMainThread()

        let callerName = call.callerName
        adaptee.reportMissedCall(call, callerName: callerName)
    }

    internal func startOutgoingCall(call: SignalCall) {
        AssertIsOnMainThread()

        adaptee.startOutgoingCall(call: call)
    }

    @objc public func answerCall(localId: UUID) {
        AssertIsOnMainThread()

        adaptee.answerCall(localId: localId)
    }

    internal func answerCall(_ call: SignalCall) {
        AssertIsOnMainThread()

        adaptee.answerCall(call)
    }

    internal func didTerminateCall(_ call: SignalCall?, hasCallInProgress: Bool) {
        AssertIsOnMainThread()

//        // If the call we're terminating was terminated due to "busy", we still have a call in
//        // progress, otherwise, we terminate the audio.
//        if !hasCallInProgress {
//            self.audioSession.isRTCAudioEnabled = false
//        }
//        if let call = call {
//            self.audioSession.endAudioActivity(call.audioActivity)
//        }
    }

    @objc public func startAndShowOutgoingCall(address: SignalServiceAddress, hasLocalVideo: Bool) {
        AssertIsOnMainThread()

        adaptee.startAndShowOutgoingCall(address: address, hasLocalVideo: hasLocalVideo)
    }

    internal func recipientAcceptedCall(_ call: SignalCall) {
        AssertIsOnMainThread()

        adaptee.recipientAcceptedCall(call)
    }

    internal func remoteDidHangupCall(_ call: SignalCall) {
        AssertIsOnMainThread()

        adaptee.remoteDidHangupCall(call)
    }

    internal func remoteBusy(_ call: SignalCall) {
        AssertIsOnMainThread()

        adaptee.remoteBusy(call)
    }

    internal func didAnswerElsewhere(call: SignalCall) {
        adaptee.didAnswerElsewhere(call: call)
    }

    internal func didDeclineElsewhere(call: SignalCall) {
        adaptee.didDeclineElsewhere(call: call)
    }

    internal func localHangupCall(localId: UUID) {
        AssertIsOnMainThread()

        adaptee.localHangupCall(localId: localId)
    }

    internal func localHangupCall(_ call: SignalCall) {
        AssertIsOnMainThread()

        adaptee.localHangupCall(call)
    }

    internal func failCall(_ call: SignalCall, error: CallError) {
        AssertIsOnMainThread()

        adaptee.failCall(call, error: error)
    }

    internal func showCall(_ call: SignalCall) {
        AssertIsOnMainThread()

        adaptee.showCall(call)
    }

    internal func setIsMuted(call: SignalCall, isMuted: Bool) {
        AssertIsOnMainThread()

        // With CallKit, muting is handled by a CXAction, so it must go through the adaptee
        adaptee.setIsMuted(call: call, isMuted: isMuted)
    }

    internal func setHasLocalVideo(call: SignalCall, hasLocalVideo: Bool) {
        AssertIsOnMainThread()

        adaptee.setHasLocalVideo(call: call, hasLocalVideo: hasLocalVideo)
    }

    internal func setAudioSource(call: SignalCall, audioSource: AudioSource?) {
        AssertIsOnMainThread()

        // AudioSource is not handled by CallKit (e.g. there is no CXAction), so we handle it w/o going through the
        // adaptee, relying on the AudioService CallObserver to put the system in a state consistent with the call's
        // assigned property.
        call.audioSource = audioSource
    }

    internal func setCameraSource(call: SignalCall, isUsingFrontCamera: Bool) {
        AssertIsOnMainThread()

//        callService.setCameraSource(call: call, isUsingFrontCamera: isUsingFrontCamera)
    }

    // CallKit handles ringing state on it's own. But for non-call kit we trigger ringing start/stop manually.
    internal var hasManualRinger: Bool {
        AssertIsOnMainThread()

        return adaptee.hasManualRinger
    }

    // MARK: - CallServiceObserver

    internal func didUpdateCall(call: SignalCall?) {
        AssertIsOnMainThread()

        call?.addObserverAndSyncState(observer: audioService)
    }

    internal func didUpdateVideoTracks(call: SignalCall?,
                                       localCaptureSession: AVCaptureSession?,
                                       remoteVideoTrack: RTCVideoTrack?) {
        AssertIsOnMainThread()

        audioService.didUpdateVideoTracks(call: call)
    }
}
