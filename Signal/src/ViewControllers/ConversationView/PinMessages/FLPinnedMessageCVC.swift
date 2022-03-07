//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

class FLPinnedMessageCVC: FLBaseCVC {
    @IBOutlet weak var titleLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var orderImg: UIImageView!
    @IBOutlet weak var thumbImg: UIImageView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var stackRightMargin: NSLayoutConstraint!
    var actionBlock:FLActionBlock?
    
    override class func cellSize(_ clv: UICollectionView?, _ model: Any?) -> CGSize {
        let width = clv?.frameWidth ?? WIDTH_SCREEN
        let height:CGFloat = 60
        return CGSize(width: width, height: height)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        
        orderImg.image = UIImage(named: "ico-six-dot")?.withRenderingMode(.alwaysTemplate)
        orderImg.tintColor = .black
        
        deleteBtn.setImage(UIImage(named: "trash-solid-24")?.withRenderingMode(.alwaysTemplate), for: .normal)
        deleteBtn.tintColor = .black
    }

    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLbl.text = nil
        descLbl.text = nil
        thumbImg.alpha = 0
    }
    
    @IBAction func deleteBtnTouch(_ sender: Any) {
        actionBlock?((self, "delete", model))
    }
    
    func updateData(_ obj: Any?, state: PinMessageListViewState) {
        model = obj
        if state == .edit {
            stackRightMargin.constant = 40
            deleteBtn.isHidden = false
            orderImg.isHidden = false
        }else {
            stackRightMargin.constant = state == .normal ? 2 : 15
            deleteBtn.isHidden = true
            orderImg.isHidden = true
        }
        stackView.setNeedsUpdateConstraints()
        stackView.superview?.layoutIfNeeded()
    }
    
    override var model: Any? {
        didSet {
            if let item = model as? TSInfoMessage {
                self.bindingData(item)
            }
        }
    }
    
    private func bindingData(_ item: TSInfoMessage) {
        DATABASE_STORE.uiRead { [weak self] trans in
            guard let self = self else { return }
            
            var cellType:OWSMessageCellType = .textOnlyMessage
            var bodyText = ""
            var cachedAttatchMent:TSAttachmentStream?
            if let message = item.message(trans: trans) {
                //Reference albumItemsForMediaAttachments of ConversationInteractionViewItem
                let mediaAttachments = message.mediaAttachments(with: trans.unwrapGrdbRead)
                if  mediaAttachments.count > 0 {
                    cellType = .mediaMessage
                    for attachment in mediaAttachments {
                        if !attachment.isVisualMedia {
                            cellType = .textOnlyMessage
                            break
                        }
                        if let attachmentStream = attachment as? TSAttachmentStream {
                            cachedAttatchMent = attachmentStream
                        }
                    }
                    if cellType == .textOnlyMessage {
                        if let mediaAttachment = mediaAttachments.first {
                            if let attachmentStream = mediaAttachment as? TSAttachmentStream {
                                cachedAttatchMent = attachmentStream
                                if attachmentStream.isAudio {
                                    let audioDuration = attachmentStream.audioDurationSeconds()
                                    cellType = audioDuration > 0 ? .audio : .genericAttachment
                                }else {
                                    cellType = .genericAttachment
                                }
                                bodyText = attachmentStream.sourceFilename ?? ""
                            }
                            else if let attachmentPointer = mediaAttachment as? TSAttachmentPointer {
                                if attachmentPointer.isAudio {
                                    cellType = .audio
                                }else {
                                    cellType = .genericAttachment
                                }
                                bodyText = attachmentPointer.sourceFilename ?? ""
                            }
                        }
                    }
                }
            }
            switch cellType {
            case .audio:
                self.titleLbl.text = "[Audio] \(bodyText)"
            case .mediaMessage:
                self.titleLbl.text = "[Photo] \(bodyText)"
                if let att = cachedAttatchMent {
                    if att.isVideo {
                        self.titleLbl.text = "[Video] \(bodyText)"
                    }
                    else if att.isAudio {
                        self.titleLbl.text = "[Audio] \(bodyText)"
                    }
                    else if att.isAnimated {
                        self.titleLbl.text = "[Gif] \(bodyText)"
                    }
                }
            case .genericAttachment:
                self.titleLbl.text = "[File] \(bodyText)"
            default:
                self.titleLbl.text = item.message(trans: trans)?.body
            }
            if let ima = cachedAttatchMent?.originalImage,
               ima.size.width > 0 {
                self.thumbImg.alpha = 1
                self.thumbImg.image = ima
            }
            else if cellType == .audio ||
                        cellType == .genericAttachment {
                self.thumbImg.alpha = 1
                self.thumbImg.image = UIImage(named: "file-outline-24")
            }
            if let authorMsgName = item.authorMessageName(trans: trans),
               !authorMsgName.isEmpty {
                let format = FLLocalize("MESSAGE_OF")
                self.descLbl.text = String(format: format, authorMsgName)
            }
        }
        
//        cachedAttatchMent?.thumbnailImageSmall(success: { ima in
//            let size = ima.size
//            if size.width > 0 {
//                self.thumbImg.isHidden = false
//                self.thumbImg.image = ima
//            }
//        }, failure: {
//
//        })
    }
}
