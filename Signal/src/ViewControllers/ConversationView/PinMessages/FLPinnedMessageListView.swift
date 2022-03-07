//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit
import PureLayout

//TODO: Localizable this view

private let CELL_HEIGHT:CGFloat = 60

enum PinMessageListViewState {
    case none, normal, expand, edit
}

class FLPinnedMessageListView: FLBaseView {
    @IBOutlet weak var mainStackView: UIStackView!
    @IBOutlet weak var topPaddingView: UIView!
    
    @IBOutlet weak var editHeaderView: UIView!
    @IBOutlet weak var pinIcon: UIImageView!
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var containerStackView: UIStackView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var collapseBtn: UIButton!
    @IBOutlet weak var clv: UICollectionView!
    @IBOutlet weak var expandView: UIView!
    @IBOutlet weak var expandArrowContainerView: UIView!
    
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var expandBtn: UIButton!
    
    @IBOutlet weak var editBottomView: UIView!
    @IBOutlet weak var containerHeight: NSLayoutConstraint!
    @IBOutlet weak var topPaddingHeight: NSLayoutConstraint!
    
    @IBOutlet weak var closeBtn: UIButton!
    @IBOutlet weak var saveBtn: UIButton!
    
    @IBOutlet weak var editPinMessageLbl: UILabel!
    @IBOutlet weak var subEditPinMessageLbl: UILabel!
    @IBOutlet weak var listPinMessageLbl: UILabel!
    @IBOutlet weak var editBtn: UIButton!
    
    
    var state:PinMessageListViewState = .none
    var originOrder = [Int]()
    var marginConstraints = [NSLayoutConstraint]()
    var converStateView:UIView!
    var isFullscreenStyle = false
    var actionBlock:FLActionBlock?
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard state != .edit else {
            return
        }
        if let touch = touches.first {
            let point = touch.location(in: self)
            if isFullscreenStyle {
                if !containerView.frame.contains(point) &&
                    !bottomView.frame.contains(point) {
                    changeState(.normal)
                }
            }else {
                if expandBtn.convert(expandBtn.frame, to: self).contains(point) {
                    actionBlock?((self, "expand", nil))
                }
            }
        }
    }
    
    func changeState(_ value: PinMessageListViewState, animated: Bool = true, completion: FLVoidBlock? = nil) {
        guard state != value,
              let _ = superview else {
            return
        }
        state = value
        if state == .edit {
            originOrder.removeAll()
            for infoMsg in items {
                guard let userInfo = infoMsg.infoMessageUserInfo,
                      let _ = userInfo[.pinMessageId] as? String else {
                    continue
                }
                originOrder.append(infoMsg.pinMessageSequence)
            }
        }
        layoutByState(animated, completion: completion)
    }
    
    private func layoutByState(_ animated: Bool = true, completion: FLVoidBlock?) {
        guard let window = superview else {
            return
        }
        //Reset save button
        
        if items.count > 1 {
            expandBtn.alpha = 1
            expandBtn.setTitle("+\(items.count - 1)", for: .normal)
            expandArrowContainerView.isHidden = true
        }else {
            expandArrowContainerView.isHidden = false
            expandBtn.alpha = 0
        }
        if !self.isFullscreenStyle {
            clipsToBounds = true
            headerView.isHidden = true
            bottomView.isHidden = true
            expandView.superview?.isHidden = false
            editHeaderView.isHidden = true
            editBottomView.isHidden = true
            topPaddingView.isHidden = true
            containerHeight.constant = CELL_HEIGHT
            backgroundColor = .clear
            
            updateAfterChangeConstraint(0) { [weak self] in
                guard let self = self else { return }
                
                self.clv.reloadData()
                completion?()
            }
            return
        }
        saveBtn.isEnabled = false
        
        let topSafeArea = window.safeAreaInsets.top
        let topViewSafeArea = converStateView.safeAreaInsets.top
        
        var topPadding:CGFloat = 0
        var contanerHeight:CGFloat = window.frameHeight
        switch state {
        case .normal:
            headerView.isHidden = true
            bottomView.isHidden = true
            expandView.superview?.isHidden = false
            editHeaderView.isHidden = true
            editBottomView.isHidden = true
            backgroundColor = .clear
            
            topPadding = topViewSafeArea + 5
            contanerHeight = CELL_HEIGHT
        case .expand:
            expandView.superview?.isHidden = true
            headerView.isHidden = false
            bottomView.isHidden = false
            editHeaderView.isHidden = true
            editBottomView.isHidden = true
            backgroundColor = UIColor.black.withAlphaComponent(0.9)
            
            topPadding = topViewSafeArea + 5
            contanerHeight = CGFloat(items.count) * CELL_HEIGHT + headerView.frameHeight
        case .edit:
            
            headerView.isHidden = true
            bottomView.isHidden = true
            expandView.superview?.isHidden = true
            editHeaderView.isHidden = false
            editBottomView.isHidden = false
            backgroundColor = UIColor.ows_gray05
            
            //Recalculate editHeaderView height
            editHeaderView.setNeedsLayout()
            editHeaderView.layoutIfNeeded()
            topPadding = topSafeArea
            contanerHeight = window.frameHeight - (topPadding + editBottomView.frameHeight + editHeaderView.frameHeight)
            
        default:
            debugPrint("Unhandle")
        }
        //To avoid animation
        containerStackView.setNeedsLayout()
        containerStackView.layoutIfNeeded()
        clv.reloadData()
        
        topPaddingHeight.constant = topPadding
        containerHeight.constant = contanerHeight
        
        updateAfterChangeConstraint(animated ? 0.2 : 0) { [weak self] in
            guard let self = self else { return }
            
            self.clv.reloadData()
            completion?()
            if self.isFullscreenStyle,
               self.state == .normal {
                self.actionBlock?((self, "collape", nil))
            }
        }
    }
    
    var items = [TSInfoMessage]()
    
    func updateItems(_ infoMessages: [TSInfoMessage]) {
        items = infoMessages
        clv.reloadData()
        isHidden = items.count == 0
        if items.count > 0 {
            if items.count > 1 {
                expandBtn.alpha = 1
                expandBtn.setTitle("+\(items.count - 1)", for: .normal)
                expandArrowContainerView.isHidden = true
            }else {
                expandArrowContainerView.isHidden = false
                expandBtn.alpha = 0
            }
            if state != .normal {
                layoutByState(false, completion: nil)
            }
        }
    }
    override func draw(_ rect: CGRect) {
        super.draw(rect)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        headerView.isHidden = true
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongGesture(gesture:)))
        longPressGesture.minimumPressDuration = 0.1
        longPressGesture.delegate = self
        clv.addGestureRecognizer(longPressGesture)
    }
    
    @IBAction func expandBtnTouch(_ sender: Any) {
        window?.endEditing(true)
        
        if isFullscreenStyle {
            changeState(.expand)
        }else {
            actionBlock?((self, "expand", nil))
        }
    }
    
    @IBAction func collapseBtnTouch(_ sender: Any) {
        changeState(.normal)
    }
    
    @IBAction func editBtnTouch(_ sender: Any) {
        changeState(.edit)
    }
    
    @IBAction func closeBtnTouch(_ sender: Any) {
        changeState(.expand)
        if saveBtn.isEnabled {
            actionBlock?((self, "discardReorder", nil))
        }
    }
    
    @IBAction func saveBtnTouch(_ sender: Any) {
        changeState(.expand) { [weak self] in
            guard let self = self else { return }
            
            var result = [String: Any]()
            for (i, infoMsg) in self.items.enumerated() {
                guard let userInfo = infoMsg.infoMessageUserInfo,
                      let messageId = userInfo[.pinMessageId] as? String else {
                    continue
                }
                if i < self.originOrder.count {
                    let data = ["messageId": messageId,
                                "infoMsg": infoMsg,
                                "sequence": self.originOrder[i]] as [String : Any]
                    result[infoMsg.uniqueId] = data
                }
            }
            self.actionBlock?((self, "reorder", result))
        }
    }
    
    func didUnpinMessage(_ msgInfo: TSInfoMessage) {
        guard let idx = items.firstIndex(where: { $0.uniqueId == msgInfo.uniqueId}),
              idx < clv.numberOfItems(inSection: 0) else {
            return
        }
        
        let ip = IndexPath(item: idx, section: 0)
        clv.performBatchUpdates { [weak self] in
            guard let self = self else { return }
            self.items.remove(at: ip.item)
            if ip.item < self.originOrder.count {
                self.originOrder.remove(at: ip.item)
            }
            self.clv.deleteItems(at: [ip])
        } completion: { [weak self] _ in
            guard let self = self else { return }
            
            self.clv.reloadData()
            if self.items.count == 0 {
                self.changeState(.normal, animated: false)
                self.isHidden = true
            }
        }

    }
    private func setupUI() {
        
        backgroundColor = .clear
        
        containerView.backgroundColor = UIColor.ows_gray05
        containerView.border(radius: 5)
        
        clv.backgroundColor = .clear
        clv.dataSource = self
        clv.delegate = self
        clv.registerCell(FLPinnedMessageCVC.cellId)
        clv.collectionViewLayout = FLUtils.verticalFlowLayout
        
        if let ima = UIImage(named: "navbar_disclosure_down")?.rotate(radians: .pi) {
            collapseBtn.setImage(ima, for: .normal)
        }
        
        expandArrowContainerView.border(.lightGray, width: 1, radius: expandArrowContainerView.frameHeight/2.0)
        expandBtn.border(.lightGray, width: 1, radius: expandBtn.frameHeight/2)
        expandBtn.setImage(UIImage(named: "navbar_disclosure_down")?.withRenderingMode(.alwaysTemplate), for: .normal)
        expandBtn.tintColor = .black
        
        pinIcon.image = UIImage(named: "pin-message-solid-24")?.withRenderingMode(.alwaysTemplate)
        pinIcon.tintColor = .black
        if let v = pinIcon.superview {
            v.backgroundColor = UIColor.ows_accentYellow
            v.border(radius: v.frameHeight/2)
        }
        pinIcon.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(expandBtnTouch(_:)))
        pinIcon.addGestureRecognizer(tapGesture)
        
        closeBtn.backgroundColor = UIColor(red: 67/255, green: 68/255, blue: 73/255, alpha: 1)
        closeBtn.border(radius: closeBtn.frameHeight/2)
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.setTitleColor(.lightGray, for: .disabled)
        
        saveBtn.setBackgroundColor(UIColor(red: 122/255, green: 129/255, blue: 137/255, alpha: 1), state: .disabled)
        saveBtn.setBackgroundColor(UIColor.ows_accentBlue, state: .normal)
        saveBtn.border(radius: saveBtn.frameHeight/2)
        
        // set localized
        saveBtn.setTitle(NSLocalizedString("ALERT_SAVE", comment: ""), for: .normal)
        closeBtn.setTitle(NSLocalizedString("CLOSE", comment: ""), for: .normal)
        collapseBtn.setTitle(NSLocalizedString("COLLAPSE", comment: ""), for: .normal)
        editPinMessageLbl.text = NSLocalizedString("EDIT_PIN_MESSAGE", comment: "")
        subEditPinMessageLbl.text = NSLocalizedString("SUB_EDIT_PIN_MESSAGE", comment: "")
        listPinMessageLbl.text = NSLocalizedString("LIST_PINNED_MESSAGES", comment: "")
        editBtn.setTitle(NSLocalizedString("CONTACT_EDIT_NAME_BUTTON", comment: ""), for: .normal)
    }
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        switch(gesture.state) {
        case .began:
            guard let selectedIndexPath = clv.indexPathForItem(at: gesture.location(in: clv)) else {
                break
            }
            clv.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            clv.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case .ended:
            clv.endInteractiveMovement()
        default:
            clv.cancelInteractiveMovement()
        }
    }
}

extension FLPinnedMessageListView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FLPinnedMessageCVC.cellId, for: indexPath) as! FLPinnedMessageCVC
        cell.updateData(items[indexPath.item], state: state)
        if state == .normal,
           items.count == 1,
           cell.thumbImg.alpha > 0 {
            cell.stackRightMargin.constant = 0
            cell.stackView.setNeedsUpdateConstraints()
            cell.stackView.superview?.layoutIfNeeded()
        }
        cell.actionBlock = { [weak self] (action) in
            guard let self = self else { return }
            
            self.actionBlock?((self, action.type, action.obj))
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return FLPinnedMessageCVC.cellSize(collectionView, items[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard state != .edit else {
            return
        }
        actionBlock?((self, "select", items[indexPath.item]))
        if state == .expand {
            changeState(.normal, animated: false)
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return state == .edit && items.count > 1
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        print("Changing the cell order, moving: \(sourceIndexPath.row) to \(destinationIndexPath.row)")
        let temp = items.remove(at: sourceIndexPath.item)
        items.insert(temp, at: destinationIndexPath.item)
        saveBtn.isEnabled = true
    }
}

extension FLPinnedMessageListView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let longGesgure = gestureRecognizer as? UILongPressGestureRecognizer {
            if state != .edit {
                return false
            }
            if items.count <= 1 {
                return false
            }
            let point = longGesgure.location(in: clv)
            if let ip = clv.indexPathForItem(at: point),
               let cell = clv.cellForItem(at: ip) as? FLPinnedMessageCVC,
               cell.deleteBtn.isHidden == false {
                let deleteBtnFrame = cell.deleteBtn.convert(cell.deleteBtn.bounds, to: clv)
                if deleteBtnFrame.contains(point) {
                    return false
                }
            }
        }
        return true
    }
}
