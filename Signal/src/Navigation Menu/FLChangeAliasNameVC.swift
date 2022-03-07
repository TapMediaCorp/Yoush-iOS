//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

class FLChangeAliasNameVC: UIViewController {
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var descLbl: UILabel!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var saveBtn: UIButton!
    
    var contactThread: TSContactThread?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationItem.leftBarButtonItem = UIViewController.createOWSBackButton(withTarget: self,
                                                                                selector: #selector(backButtonPressed))
        
        view.backgroundColor = Theme.backgroundColor
        
        textField.textColor = Theme.primaryTextColor
        textField.border(radius: 5)
        textField.backgroundColor = Theme.searchFieldBackgroundColor
        textField.delegate = self
        
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: textField.frameHeight))
        v.backgroundColor = .clear
        textField.leftView = v
        textField.leftViewMode = .always
        v.autoSetDimension(.width, toSize: 15)
        
        cancelBtn.setTitle(FLLocalize("TXT_CANCEL_TITLE"), for: .normal)
        cancelBtn.backgroundColor = UIColor(red: 67/255, green: 68/255, blue: 73/255, alpha: 1)
        cancelBtn.border(radius: cancelBtn.frameHeight/2)
        
        saveBtn.setTitle(FLLocalize("PROFILE_VIEW_SAVE_BUTTON"), for: .normal)
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.setBackgroundColor(UIColor.ows_accentBlue, state: .normal)
        saveBtn.border(radius: saveBtn.frameHeight/2)
        if let thread = contactThread {
            let contactManager = Environment.shared.contactsManager
            var originalName = ""
            var currentName = ""
            DATABASE_STORE.read { trans in
                currentName = contactManager?.displayName(for: thread, transaction: trans) ?? ""
                if let profileName = OWSProfileManager.shared().fullName(for: thread.contactAddress, transaction: trans),
                   profileName.count > 0 {
                    originalName = profileName
                }
                else if let username = OWSProfileManager.shared().username(for: thread.contactAddress, transaction: trans),
                        username.count > 0 {
                    originalName = username
                }
            }
            
            if originalName.count > 0,
               currentName.count > 0{
                textField.placeholder = originalName
                if originalName != currentName {
                    textField.text = currentName
                }
                let messageFormat = FLLocalize("CHANGE_ALIAS_DES")
                let str = String(format: messageFormat, originalName)
                let att = NSMutableAttributedString(string: str, attributes: [.font : descLbl.font!,
                                                                              .foregroundColor: descLbl.textColor!])
                let range = (str as NSString).range(of: originalName)
                if range.location != NSNotFound {
                    att.addAttributes([.font : UIFont.boldSystemFont(ofSize: descLbl.font!.pointSize)], range: range)
                }
                
                descLbl.attributedText = att
            }
            else if currentName.count > 0 {
                let messageFormat = FLLocalize("CHANGE_ALIAS_DES")
                let str = String(format: messageFormat, currentName)
                let att = NSMutableAttributedString(string: str, attributes: [.font : descLbl.font!,
                                                                              .foregroundColor: descLbl.textColor!])
                let range = (str as NSString).range(of: currentName)
                if range.location != NSNotFound {
                    att.addAttributes([.font : UIFont.boldSystemFont(ofSize: descLbl.font!.pointSize)], range: range)
                }
                
                descLbl.attributedText = att
            }
        }
    }
    
    @objc
    public func backButtonPressed(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func cancelBtnTouch(_ sender: Any) {
        backButtonPressed(sender)
    }
    
    @IBAction func saveBtnTouch(_ sender: Any) {
        let aliasName = textField.text?.stripped ?? ""
        if let thread = contactThread,
           let phoneNumber = thread.contactPhoneNumber,
           let userDefaults = UserDefaults(suiteName: TSConstants.applicationGroup) {
            let key = "NAME_ALIAS_\(phoneNumber)"
            userDefaults.setValue(aliasName, forKey: key)
            userDefaults.synchronize()
        }
        DATABASE_STORE.write { trans in
            self.contactThread?.anyUpdateContactThread(transaction: trans, block: { thread in
                thread.nameAlias = aliasName
            })
        }
        navigationController?.popViewController(animated: true)
        let notiName = NSNotification.Name("DidUpdateAlias")
        NTF_CENTER.post(name: notiName, object: nil)
    }
}

extension FLChangeAliasNameVC: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // get the current text, or use an empty string if that failed
        let currentText = textField.text ?? ""
        
        // attempt to read the range they are trying to change, or exit if we can't
        guard let stringRange = Range(range, in: currentText) else { return true }
        
        // add their new text to the existing text
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        let specialCharacterSet = CharacterSet(charactersIn: "~!@#$%^&*()_+`-=[]\\{}|:;'<>?,./")
        
        if updatedText.rangeOfCharacter(from: specialCharacterSet) != nil {
            return false
        }
        if updatedText.containsEmoji {
            return false
        }
        
        return true
    }
}
