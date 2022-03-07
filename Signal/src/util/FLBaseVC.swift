//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

class FLBaseVC: UIViewController {
    @IBOutlet var contentView: UIView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
    }
    
    deinit {
        NTF_CENTER.removeObserver(self)
    }
    
    /// Action when pop view
    @objc
    @IBAction func backAction(_ sender: Any? = nil) {
        view.endEditing(true)
        prepareToRelease()
        navigationController?.popViewController(animated: true)
    }
    
    /// Action when dismiss view
    @IBAction func closeAction(_ sender: Any? = nil) {
        view.endEditing(true)
        prepareToRelease()
        dismiss(animated: true, completion: nil)
    }
    
    internal func setupUI() {
        
    }
    
    internal func prepareToRelease() {
        NTF_CENTER.removeObserver(self)
    }
}

extension UIViewController {
    class func instance(_ storyboard:UIStoryboard = BAStoryboard.main, _ identifier: String? = nil) -> Self {
        return instanceHelper(storyboard, identifier ?? self.classNameString)
    }
    
    private class func instanceHelper<T>(_ storyboard:UIStoryboard, _ identifier: String) -> T {
        return storyboard.instantiateViewController(withIdentifier: identifier) as! T
    }
}

struct BAStoryboard {
    static let main = UIStoryboard(name: "Main", bundle: nil)
}
