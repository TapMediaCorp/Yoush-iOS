//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

let USER_DEFAULT = UserDefaults.standard
let NTF_CENTER = NotificationCenter.default
let WIDTH_SCREEN = UIScreen.main.bounds.size.width
let HEIGHT_SCREEN = UIScreen.main.bounds.size.height

//A Shorter NSLocalizedString version
public func FLLocalize(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

typealias FLAnyBlock = (_ obj: (value: Any?, error: Error?)) -> Void
typealias FLActionBlock = (_ action: (sender:Any?, type: String, obj: Any?) ) -> Void
typealias FLVoidBlock = () -> Void

var DATABASE_STORE:SDSDatabaseStorage {
    return SDSDatabaseStorage.shared
}

var CALL_SERVIVE:CallService {
    return AppEnvironment.shared.callService
}

@objc
extension NSObject {
    static var classNameString: String {
        return NSStringFromClass(self).components(separatedBy: ".").last!
    }
    
    var classNameString: String {
        return NSStringFromClass(type(of: self)).components(separatedBy: ".").last!
    }
    
    func addNotification(_ name: Notification.Name, selector: Selector) {
        NTF_CENTER.addObserver(self, selector: selector, name: name, object: nil)
    }
}

@objc
class FLBaseView: UIView {
    @objc
    class func instance(nibName: String? = nil, frame: CGRect) -> Self {
        return instanceHelper(nibName ?? self.classNameString, frame: frame)
    }
    
    private class func instanceHelper<T>(_ nibName: String, frame: CGRect) -> T {
        let instance = Bundle.main.loadNibNamed(nibName, owner: self, options: nil)?.last as! T
        if let instance = instance as? UIView {
            instance.frame = frame
        }
        return instance
    }
}

extension UIView {
    func border(_ color: UIColor? = nil, width: CGFloat = 1, radius: CGFloat) {
        if let color = color {
            layer.borderWidth = width
            layer.borderColor = color.cgColor
            layer.cornerRadius = radius
        }else {
            layer.borderWidth = 0
            layer.cornerRadius = radius
        }
        layer.masksToBounds = true
    }
    
    func updateAfterChangeConstraint(_ duration: TimeInterval? = 0, completion: FLVoidBlock? = nil) {
        setNeedsUpdateConstraints()
        if duration != nil,
           duration! > 0 {
//            UIView.animate(withDuration: duration!) { [weak self] in
//                self?.superview?.layoutIfNeeded()
//            } completion: { _ in
//                completion?()
//            }
            UIView.animate(
                withDuration: duration!,
                delay: 0,
                options: [.beginFromCurrentState, .curveLinear],
                animations: { [weak self] in
                    self?.superview?.layoutIfNeeded()
                }) { _ in
                completion?()
            }
        }else {
            superview?.layoutIfNeeded()
            completion?()
        }
    }
    
}

@objc
extension UIView {
    var frameWidth:CGFloat {
        get {
            return self.frame.size.width
        }set {
            self.frame.size = CGSize(width: newValue, height: self.frame.size.height)
        }
    }
    
    var frameHeight:CGFloat {
        get {
            return self.frame.size.height
        }set {
            self.frame.size = CGSize(width: self.frame.size.width, height: newValue)
        }
    }
    
    var frameSize:CGSize {
        get {
            return self.frame.size
        }set {
            self.frame.size = newValue
        }
    }
    
    var frameX:CGFloat {
        get {
            return self.frame.origin.x
        }set {
            self.frame.origin = CGPoint(x: newValue, y: self.frame.origin.y)
        }
    }
    
    var frameY:CGFloat {
        get {
            return self.frame.origin.y
        }set {
            self.frame.origin = CGPoint(x: self.frame.origin.x, y: newValue)
        }
    }
    
    var frameOrigin:CGPoint {
        get {
            return self.frame.origin
        }set {
            self.frame.origin = newValue
        }
    }
    
    var frameRight:CGFloat {
        get {
            return self.frame.origin.x + self.frame.size.width
        }
    }
    
    var frameBottom:CGFloat {
        get {
            return self.frame.origin.y + self.frame.size.height
        }
    }
}

extension UICollectionView {
    func registerCell(_ cellId:String) {
        register(UINib.init(nibName: cellId, bundle: Bundle.main), forCellWithReuseIdentifier: cellId)
    }
    
    func registerHeader(_ headerId:String) {
        let nib = UINib.init(nibName: headerId, bundle: Bundle.main)
        register(nib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerId)
    }
    
    func registerEmptyCell() {
        register(UICollectionViewCell.self, forCellWithReuseIdentifier: "FL_EmptyCell")
    }
    
    func emptyCell(_ atIndexPath: IndexPath) -> UICollectionViewCell {
        return dequeueReusableCell(withReuseIdentifier: "FL_EmptyCell", for: atIndexPath)
    }
    
    var flowLayout:UICollectionViewFlowLayout? {
        return collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    var orderVisibleIndexPaths:[IndexPath] {
        var indexPaths = indexPathsForVisibleItems
        indexPaths.sort { (ip1, ip2) -> Bool in
            if ip1.section == ip2.section {
                return ip1.item < ip2.item
            }
            return ip1.section < ip2.section
        }
        return indexPaths
    }
    
    func reloadWithoutAnimation() {
        UIView.performWithoutAnimation { [weak self] in
            guard let sSelf = self else { return }
            
            sSelf.reloadData()
        }
    }
}

class FLUtils: NSObject {
    static var verticalFlowLayout: FLCollectionViewFlowLayout {
        let layout = FLCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout;
    }
    
    static var horizontalFlowLayout: FLCollectionViewFlowLayout {
        let layout = FLCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout;
    }
}

class FLCollectionViewFlowLayout: UICollectionViewFlowLayout {
    var triggerContentSize = false
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override var collectionViewContentSize: CGSize {
        var contentSize = super.collectionViewContentSize
        if triggerContentSize == true,
           let clv = collectionView,
           contentSize.height <= clv.frameHeight {
            contentSize.height = clv.frameHeight + 1
        }
        return contentSize
    }
}

extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}

import SignalMessaging
import SignalMetadataKit
import SignalServiceKit
//import WebRTC
//import SignalRingRTC

fileprivate extension FLUtils {
    class func sendInfoMessage(_ thread:TSThread, message: TSOutgoingMessage, recipient:  SignalRecipient, senderCertificate: SMKSenderCertificate?, trans: SDSAnyWriteTransaction) {
        var plainText:Data?
        SDSDatabaseStorage.shared.read { trans in
            plainText = message.buildPlainTextData(recipient, thread: thread, transaction: trans)
        }
        //Create message send
        var sendingAccessMap = [SignalServiceAddress: OWSUDSendingAccess]()
        if senderCertificate != nil {
            SDSDatabaseStorage.shared.write { trans in
                if recipient.address.isLocalAddress == false {
                    sendingAccessMap[recipient.address] = SSKEnvironment.shared.udManager.udSendingAccess(forAddress: recipient.address, requireSyncAccess: true, senderCertificate: senderCertificate!, transaction: trans)
                }
            }
        }

        let udSendingAccess = sendingAccessMap[recipient.address];

        let messageSend = OWSMessageSend(message: message, thread: thread, recipient: recipient, udSendingAccess: udSendingAccess, localAddress: TSAccountManager.sharedInstance().localAddress!, sendErrorBlock: nil)
        //build json data
        let messageSender = SSKEnvironment.shared.messageSender
        var messages = [Any]()

//        let deviceIds = messageSend.deviceIds
//        for deviceId in deviceIds {
//            messageSender.throws_ensureRecipientHasSession(for: messageSend, deviceId: deviceId)
//        }
        SDSDatabaseStorage.shared.write { trans in
            for deviceId in messageSend.deviceIds {
                var jsonData = [String:Any]()
                let cipher = SessionCipher(sessionStore: SSKEnvironment.shared.sessionStore, preKeyStore: SSKEnvironment.shared.preKeyStore, signedPreKeyStore: SSKEnvironment.shared.signedPreKeyStore, identityKeyStore: SSKEnvironment.shared.identityManager, recipientId: messageSend.recipient.accountId, deviceId: deviceId.int32Value)
                
                let encryptedData = self.serializedMessage(messageSend, deviceId: deviceId, plainText: plainText!, senderCertificate: senderCertificate, transaction: trans)
                jsonData["content"] = encryptedData.0!.base64EncodedString(options:[])
                jsonData["destination"] = recipient.recipientPhoneNumber
                jsonData["destinationDeviceId"] = deviceId
//                jsonData["destinationRegistrationId"] = messageSender.throws_remoteRegistrationId(cipher, protocolContext: trans)
                jsonData["online"] = message.isOnline
                jsonData["silent"] = 1
                jsonData["type"] = encryptedData.1.rawValue
                messages.append(jsonData)
            }
//            let request = OWSRequestFactory.submitMessageRequest(with: recipient.address, messages: messages, timeStamp: message.timestamp, udAccessKey: messageSend.udSendingAccess?.udAccess.udAccessKey)
//            SSKEnvironment.shared.socketManager.make(request) { Obj in
//                debugPrint("Send message success")
//            } failure: { code, data, error in
//                debugPrint("Send message error \(error)")
//            }
        }
    }
    
    class func sendMessage(_ message: TSOutgoingMessage, senderCertificate: SMKSenderCertificate?) {
        let thread = threadForMessageWithSneakyTransaction(message)
        if let contactThread = thread as? TSContactThread {
            let recipientAddress = contactThread.recipientAddresses
            let recipient = SignalRecipient(address: recipientAddress.first!)
            var plainText:Data?
            SDSDatabaseStorage.shared.read { trans in
                plainText = message.buildPlainTextData(recipient, thread: thread, transaction: trans)
            }
            
            //Create message send
            var sendingAccessMap = [SignalServiceAddress: OWSUDSendingAccess]()
            if senderCertificate != nil {
                SDSDatabaseStorage.shared.write { trans in
                    if recipient.address.isLocalAddress == false {
                        sendingAccessMap[recipient.address] = SSKEnvironment.shared.udManager.udSendingAccess(forAddress: recipient.address, requireSyncAccess: true, senderCertificate: senderCertificate!, transaction: trans)
                    }
                }
            }
            
            let udSendingAccess = sendingAccessMap[recipient.address];
            
            let messageSend = OWSMessageSend(message: message, thread: thread, recipient: recipient, udSendingAccess: udSendingAccess, localAddress: TSAccountManager.sharedInstance().localAddress!, sendErrorBlock: nil)
            //build json data
            let messageSender = SSKEnvironment.shared.messageSender
            var messages = [Any]()
            
//            let deviceIds = messageSend.deviceIds
//            for deviceId in deviceIds {
//                messageSender.throws_ensureRecipientHasSession(for: messageSend, deviceId: deviceId)
//            }
            
            SDSDatabaseStorage.shared.write { trans in
                for deviceId in messageSend.deviceIds {
                    var jsonData = [String:Any]()
                    let encryptedData = self.serializedMessage(messageSend, deviceId: deviceId, plainText: plainText!, senderCertificate: senderCertificate, transaction: trans)
                    jsonData["content"] = encryptedData.0!.base64EncodedString(options:[])
                    jsonData["destination"] = recipient.recipientPhoneNumber
                    jsonData["destinationDeviceId"] = deviceId
//                    jsonData["destinationRegistrationId"] = 14708
                    jsonData["online"] = 0
                    jsonData["silent"] = message.isSilent
                    jsonData["type"] = encryptedData.1.rawValue
                    messages.append(jsonData)
                }
//                let request = OWSRequestFactory.submitMessageRequest(with: recipient.address, messages: messages, timeStamp: message.timestamp, udAccessKey: messageSend.udSendingAccess?.udAccess.udAccessKey)
//                SSKEnvironment.shared.socketManager.make(request) { Obj in
//                    debugPrint("Send message success")
//                } failure: { code, data, error in
//                    debugPrint("Send message error \(error)")
//                }
            }
        }
    }
    
    class func threadForMessageWithSneakyTransaction(_ message: TSMessage) -> TSThread {
        var thread:TSThread?
        SDSDatabaseStorage.shared.read { trans in
            thread = message.thread(transaction: trans)
        }
        if thread == nil {
            SDSDatabaseStorage.shared.write { trans in
                thread = message.thread(transaction: trans)
            }
        }
        return thread!
    }

    class func serializedMessage(_ messageSend: OWSMessageSend, deviceId: NSNumber, plainText: Data, senderCertificate: SMKSenderCertificate?, transaction: SDSAnyWriteTransaction) -> (Data?, TSWhisperMessageType) {
        let udSendingAcess = messageSend.udSendingAccess
        var serializedMessage:Data?
        let paddedPlaintext = (plainText as NSData).paddedMessageBody()!
        
        let cipher = SessionCipher(sessionStore: SSKEnvironment.shared.sessionStore, preKeyStore: SSKEnvironment.shared.preKeyStore, signedPreKeyStore: SSKEnvironment.shared.signedPreKeyStore, identityKeyStore: SSKEnvironment.shared.identityManager, recipientId: messageSend.recipient.accountId, deviceId: deviceId.int32Value)
            
        if (udSendingAcess != nil) {
            let secretCipher = try! SMKSecretSessionCipher(sessionStore: SSKEnvironment.shared.sessionStore, preKeyStore: SSKEnvironment.shared.preKeyStore, signedPreKeyStore: SSKEnvironment.shared.signedPreKeyStore, identityStore: SSKEnvironment.shared.identityManager)
            serializedMessage = try! secretCipher.throwswrapped_encryptMessage(recipientId: messageSend.recipient.accountId, deviceId: deviceId.int32Value, paddedPlaintext: paddedPlaintext, senderCertificate: senderCertificate!, protocolContext: transaction)
            return (serializedMessage, .unidentifiedSenderMessageType)
        } else {
            // This may throw an exception.
//            do {
//                let encryptedMessage = try! cipher.encryptMessage(paddedPlaintext, protocolContext: transaction)
//                serializedMessage = encryptedMessage.serialized()
//                return (serializedMessage, .preKeyWhisperMessageType)
//            } catch  {
//            }
            return (plainText, .unidentifiedSenderMessageType)
            
        }
    }
}

import PromiseKit

@objc
extension FLUtils {
    static var senderCeriticate:SMKSenderCertificate?
    
    @objc class func getSenderCertificate(_ completion:((_ cer: SMKSenderCertificate?) -> Void)?) {
        if senderCeriticate != nil {
            completion?(senderCeriticate)
            return
        }
        
        SSKEnvironment.shared.udManager.ensureSenderCertificate(certificateExpirationPolicy: .permissive) { val in
            senderCeriticate = val
            completion?(val)
        } failure: { error in
            completion?(nil)
        }
    }
    
    @objc
    class func deviceIds(_ group: TSGroupThread) -> [UInt32] {
        var result =  [UInt32]()
        for address in group.recipientAddresses {
            let recipient = SignalRecipient(address: address)
            for val in recipient.devices {
                guard let deviceId = val as? UInt32 else {
                    continue
                }
                result.append(deviceId)
            }
        }
        return result
    }
    
    class func recipients(_ group: TSGroupThread) -> [SignalRecipient] {
        var result =  [SignalRecipient]()
        for address in group.recipientAddresses {
            let recipient = SignalRecipient(address: address)
            result.append(recipient)
            
        }
        return result
    }
    
//    @objc
//    class func sendCallGroupMessage(_ namespace: PMKNamespacer, group: TSGroupThread, message: TSOutgoingMessage, senderCertificate:SMKSenderCertificate?)-> Promise<Void> {
//        return Promise { resolver in
//            DispatchQueue.global().async {
//                var dataToSend = [OWSMessageSend: Data]()
//                let messageSender = SSKEnvironment.shared.messageSender
//                
//                for address in group.recipientAddresses {
//        //            let recipientAddress = SignalServiceAddress(uuid: address.uuid, phoneNumber: address.phoneNumber)
//                    //Create message send
//                    var sendingAccessMap = [SignalServiceAddress: OWSUDSendingAccess]()
//                    if senderCertificate != nil {
//                        SDSDatabaseStorage.shared.write { trans in
//                            if address.isLocalAddress == false {
//                                sendingAccessMap[address] = SSKEnvironment.shared.udManager.udSendingAccess(forAddress: address, requireSyncAccess: true, senderCertificate: senderCertificate!, transaction: trans)
//                            }
//                        }
//                    }
//                    let recipient = SignalRecipient(address: address)
//                    var plainText:Data?
//                    SDSDatabaseStorage.shared.read { trans in
//                        plainText = message.buildPlainTextData(recipient, thread: group, transaction: trans)
//                    }
//                    
//                    
//                    let udSendingAccess = sendingAccessMap[recipient.address];
//                    
//                    let messageSend = OWSMessageSend(message: message, thread: group, recipient: recipient, udSendingAccess: udSendingAccess, localAddress: TSAccountManager.sharedInstance().localAddress!, sendErrorBlock: nil)
//                    
//                    let deviceIds = messageSend.deviceIds
//                    for deviceId in deviceIds {
//                        messageSender.throws_ensureRecipientHasSession(for: messageSend, deviceId: deviceId)
//                    }
//                    
//                    if let plainText = plainText {
//                        dataToSend[messageSend] = plainText
//                    }
//                }
//                SDSDatabaseStorage.shared.write { trans in
//                    var count = 0
//                    for (messageSend, plainText) in dataToSend {
//                        for deviceId in messageSend.deviceIds {
//                            let cipher = SessionCipher(sessionStore: SSKEnvironment.shared.sessionStore, preKeyStore: SSKEnvironment.shared.preKeyStore, signedPreKeyStore: SSKEnvironment.shared.signedPreKeyStore, identityKeyStore: SSKEnvironment.shared.identityManager, recipientId: messageSend.recipient.accountId, deviceId: deviceId.int32Value)
//                            
//                            var jsonData = [String:Any]()
//                            let encryptedData = self.serializedMessage(messageSend, deviceId: deviceId, plainText: plainText, senderCertificate: senderCertificate, transaction: trans)
//                            jsonData["content"] = encryptedData.0!.base64EncodedString(options:[])
//                            jsonData["destination"] = messageSend.recipient.recipientPhoneNumber
//                            jsonData["destinationDeviceId"] = deviceId
//                            jsonData["destinationRegistrationId"] = messageSender.throws_remoteRegistrationId(cipher, protocolContext: trans)
//                            jsonData["online"] = 0
//                            //                    jsonData["silent"] = 0
//                            //                    jsonData["type"] = 3
//                            jsonData["silent"] = message.isSilent
//                            jsonData["type"] = encryptedData.1.rawValue
//        //                    messages.append(jsonData)
//                            let request = OWSRequestFactory.submitMessageRequest(with: messageSend.recipient.address, messages: [jsonData], timeStamp: message.timestamp, udAccessKey: messageSend.udSendingAccess?.udAccess.udAccessKey)
//                            SSKEnvironment.shared.socketManager.make(request) { Obj in
//                                debugPrint("Send message success")
//                                count += 1
//                                if count == dataToSend.count {
//                                    DispatchQueue.main.async {
//                                        resolver.fulfill(())
//                                    }
//                                }
//                            } failure: { code, data, error in
//                                debugPrint("Send message error \(error)")
//                                count += 1
//                                if count == dataToSend.count {
//                                    DispatchQueue.main.async {
//                                        resolver.fulfill(())
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
    
}

extension UIButton{
    func setBackgroundColor(_ color: UIColor, state: UIControl.State) {
        setBackgroundImage(imageWithColor(color), for: state)
    }

    private func imageWithColor(_ color: UIColor) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size);
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(color.cgColor)
            context.fill(rect)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return image;
        }
        return nil
    }
    
}

class FLTintImageView : UIImageView {
    override func awakeFromNib() {
        super.awakeFromNib()
        if let ima = image {
            self.image = nil
            self.image = ima.withRenderingMode(.alwaysTemplate)
        }
    }
    
}

@objc
class FLCustomUI: NSObject {
    class func sectionHeaderText(_ title:String) -> NSAttributedString {
        return NSAttributedString(string: title, attributes: [.font: UIFont.boldSystemFont(ofSize: 17),
                                                              .foregroundColor : Theme.youshGoldColor])
    }
}
