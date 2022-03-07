import Foundation

class NewFriendsViewController : UIViewController {
    
    weak var composeVC: ComposeViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        self.navigationItem.title = FLLocalize("COMPOSE_MESSAGE_CONTACT_SECTION_TITLE")
        
        //Request contact permission
        
        Environment.shared.contactsManager.requestSystemContactsOnce { _ in
            let viewController = ComposeViewController()
            viewController.showDeviceContact = true
            self.addChild(viewController)
            self.view.addSubview(viewController.view)
            viewController.didMove(toParent: self)
            viewController.view.autoPinEdgesToSuperviewEdges()
            self.composeVC = viewController
        }
    }
}
