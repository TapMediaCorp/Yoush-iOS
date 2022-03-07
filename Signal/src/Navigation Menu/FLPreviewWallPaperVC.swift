//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

class FLPreviewWallPaperVC: UIViewController {
    @IBOutlet weak var conversationSnapshotImg: UIImageView!
    @IBOutlet weak var clv: UICollectionView!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var setBtn: UIButton!
    
    var images = [Any]()
    var imageIndex = 0
    var thread: TSThread?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        cancelBtn.setTitle(FLLocalize("TXT_CANCEL_TITLE"), for: .normal)
        setBtn.setTitle(FLLocalize("SET_TITLE"), for: .normal)
        if let nav = self.navigationController, nav.viewControllers.count > 1 {
            navigationItem.leftBarButtonItem = UIViewController.createOWSBackButton(withTarget: self,
                                                                                    selector: #selector(backButtonPressed))
        }
        
        clv.backgroundColor = Theme.backgroundColor
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        clv.collectionViewLayout = layout
        clv.isPagingEnabled = true
        clv.dataSource = self
        clv.delegate = self
        
        let filePath = OWSFileSystem.appDocumentDirectoryPath() + "/CURRENT_CONVERSATION_SNAPSHOT"
        let url = URL(fileURLWithPath: filePath)
        do {
            let snapshotData = try Data(contentsOf: url)
            let ima = UIImage(data: snapshotData)
            conversationSnapshotImg.image = ima
        } catch {}
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if imageIndex != 0 {
            let ip = IndexPath(item: imageIndex, section: 0)
            clv.scrollToItem(at: ip, at: .left, animated: false)
            //Reset imageIndex
            imageIndex = 0
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clv.reloadData()
    }
    
    @objc
    public func backButtonPressed(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func cancelBtnTouch(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func setBtnTouch(_ sender: Any) {
        guard let userDefaults = UserDefaults(suiteName: TSConstants.applicationGroup) else {
            return
        }
        
        guard let cell = clv.visibleCells.first as? FLSelectWallPaperCVC,
              let ima = cell.img.image,
              let data = ima.pngData() else {
            removeChatWallPaper(userDefaults)
            return
        }
        var imageUrl: String?
        if let ip = clv.indexPathsForVisibleItems.first,
           let obj = self.images[ip.item] as? FLDownloadImageObject {
            imageUrl = obj.imgUrl
        }
        changeChatWallPaper(data, imageUrl:imageUrl, userDefaults: userDefaults)
    }
    
    private func changeChatWallPaper(_ data: Data, imageUrl: String?, userDefaults: UserDefaults) {
//        //Try saving imageData with base64 string
//        let encodedString = data.base64EncodedString()
//        let encodedData = encodedString.data(using: .utf8)
//        let dataToWrite = encodedData ?? data
        let dataToWrite = data
        
        if let conthreadThread = thread as? TSContactThread,
           let phoneNumber = conthreadThread.contactPhoneNumber {
            let key = "CHAT_WALLPAPER_\(phoneNumber)"
            let filePath = OWSFileSystem.appDocumentDirectoryPath() + "/\(key)"
            let url = URL(fileURLWithPath: filePath)
            do {
                try dataToWrite.write(to: url)
                userDefaults.setValue(key, forKey: key)
                userDefaults.synchronize()
            } catch {}
        }
        
        else if let groupThread = thread as? TSGroupThread{
            let key = "CHAT_WALLPAPER_\(groupThread.uniqueId.replacingOccurrences(of: "/", with: ""))"
            let filePath = OWSFileSystem.appDocumentDirectoryPath() + "/\(key)"
            let url = URL(fileURLWithPath: filePath)
            do {
                try dataToWrite.write(to: url)
                userDefaults.setValue(key, forKey: key)
                userDefaults.synchronize()
            } catch {}
        }
        
        var userInfo = [String:Any]()
        userInfo["action"] = "set"
        userInfo["imageData"] = data
        if let imageUrl = imageUrl {
            userInfo["imageUrl"] = imageUrl
        }
        userInfo["thread"] = thread
        NotificationCenter.default.post(name: Notification.Name(rawValue: OWSConversationWallPaperDidChange), object: nil, userInfo: userInfo)
        
        //Pop to settings view
        if let nav = presentingViewController as? UINavigationController {
            nav.popViewController(animated: false)
        }
        dismiss(animated: true, completion: nil)
    }
    
    private func removeChatWallPaper(_ userDefaults: UserDefaults) {
        if let conthreadThread = thread as? TSContactThread,
           let phoneNumber = conthreadThread.contactPhoneNumber {
            let key = "CHAT_WALLPAPER_\(phoneNumber)"
            let filePath = OWSFileSystem.appDocumentDirectoryPath() + "/\(key)"
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch {}
            userDefaults.setValue(nil, forKey: key)
            userDefaults.synchronize()
        }
        
        else if let groupThread = thread as? TSGroupThread{
            let key = "CHAT_WALLPAPER_\(groupThread.uniqueId.replacingOccurrences(of: "/", with: ""))"
            let filePath = OWSFileSystem.appDocumentDirectoryPath() + "/\(key)"
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch {}
            
            userDefaults.setValue(nil, forKey: key)
            userDefaults.synchronize()
        }
        
        var userInfo = [String:Any]()
        userInfo["action"] = "remove"
        userInfo["thread"] = thread
        NotificationCenter.default.post(name: Notification.Name(rawValue: OWSConversationWallPaperDidChange), object: nil, userInfo: userInfo)
        
        //Pop to settings view
        if let nav = presentingViewController as? UINavigationController {
            nav.popViewController(animated: false)
        }
        dismiss(animated: true, completion: nil)
    }
}


extension FLPreviewWallPaperVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FLSelectWallPaperCVC", for: indexPath) as! FLSelectWallPaperCVC
        cell.reload(images[indexPath.item])
        if let obj = images[indexPath.item] as? FLDownloadImageObject {
            if let ima = obj.getOriginImage() {
                cell.activity.stopAnimating()
                cell.img.image = ima
            }else {
                cell.activity.startAnimating()
                if FLImageDownloader.shared.isDownloading(obj) == false {
                    FLImageDownloader.shared.addWallPaper(wallPaper: obj) { [weak self] (result) in
                        guard let self = self else { return }
                        
                        if let wallPaper = result.value as? FLDownloadImageObject,
                           let idx = self.images.firstIndex(where: { obj in
                            if let obj = obj as? FLDownloadImageObject,
                               obj.imgUrl == wallPaper.imgUrl {
                                return true
                            }
                            return false
                           }) {
                            let ip = IndexPath(item: idx, section: 0)
                            self.clv.reloadItems(at: [ip])
                        }
                    }
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.frameSize
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageNumber = Int(round(scrollView.contentOffset.x / scrollView.frame.size.width))
        if pageNumber < self.images.count,
           let obj = images[pageNumber] as? FLDownloadImageObject ,
              obj.getOriginImage() == nil{
            FLImageDownloader.shared.suppendAll()
            FLImageDownloader.shared.addWallPaper(wallPaper: obj) { [weak self] (result) in
                guard let self = self else { return }
                
                if let wallPaper = result.value as? FLDownloadImageObject,
                   let idx = self.images.firstIndex(where: { obj in
                    if let obj = obj as? FLDownloadImageObject,
                       obj.imgUrl == wallPaper.imgUrl {
                        return true
                    }
                    return false
                   }) {
                    let ip = IndexPath(item: idx, section: 0)
                    self.clv.reloadItems(at: [ip])
                }
            }
        }
    }
}
