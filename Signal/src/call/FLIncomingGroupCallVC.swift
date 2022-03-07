//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

class FLIncomingGroupCallVC: UIViewController {
    @IBOutlet weak var titleLbl: UILabel!
    @IBOutlet weak var statusLbl: UILabel!
    
    var groupCall:JitsiGroupCall!
    var actionBlock:FLActionBlock?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.backgroundColor = UIColor.ows_accentBlueColorBackgroundCallNew
        
        titleLbl.font = UIFont.ows_dynamicTypeTitle1
        statusLbl.font = UIFont.ows_dynamicTypeBody
        
        statusLbl.text = NSLocalizedString("IN_CALL_RINGING", comment: "Call setup status label")
        titleLbl.text = groupCall.subject
    }
    
    @IBAction func acceptBtnTouch(_ sender: Any) {
        actionBlock?((self, "accept", groupCall))
    }
    
    @IBAction func hangUpBtnTouch(_ sender: Any) {
        actionBlock?((self, "hangup", groupCall))
    }
}
