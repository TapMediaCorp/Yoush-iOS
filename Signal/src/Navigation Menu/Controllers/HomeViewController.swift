//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation

class HomeViewController :UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        //add debug gesture
        let hiddenView = UIView(frame: CGRect())
        hiddenView.backgroundColor = .clear
        view.addSubview(hiddenView)
        hiddenView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 0)
        hiddenView.autoPinEdge(toSuperviewSafeArea: .right, withInset: 0)
        hiddenView.autoSetDimensions(to: CGSize(width: 100, height: 100))
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(debugTrigger(_:)))
        gesture.numberOfTapsRequired = 2
        gesture.minimumPressDuration = 1.5
        hiddenView.addGestureRecognizer(gesture)
    }
    
    @objc
    func debugTrigger(_ gesture: UILongPressGestureRecognizer) {
        if TSConstants.isUsingProductionService {
            OWSActionSheets.showConfirmationAlert(
                title: "Đang dùng server cloudtest093",
                proceedTitle: "Đổi qua server dev-signal-chat?",
                proceedStyle: .default) { _ in
                TSConstants.forceStaging()
                
                OWSActionSheets.showActionSheet(
                    title: "Đổi qua server dev-signal-chat thành công",
                    message: "Tắt app để mở lại"
                ) { _ in
                    SignalApp.resetAppData(false)
                    //To save enviroment in user default
                    TSConstants.forceStaging()
                    exit(0)
                }
            }
        }else {
            OWSActionSheets.showConfirmationAlert(
                title: "Đang dùng server dev-signal-chat",
                proceedTitle: "Đổi qua server cloudtest093?",
                proceedStyle: .default) { _ in
                TSConstants.forceProduction()
                OWSActionSheets.showActionSheet(
                    title: "Đổi qua server cloudtest093 thành công",
                    message: "Tắt app để mở lại"
                ) { _ in
                    SignalApp.resetAppData(false)
                    //To save enviroment in user default
                    TSConstants.forceProduction()
                    exit(0)
                }
            }
        }
    }
}
