//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit
import PromiseKit
import Photos

private let IMAGES_TEMPLATE = ["https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/adam-birkett-6cXZnFCd2KQ-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/andrej-lisakov-fGZ2x8wFxC0-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/annie-spratt--KKLWDAgj2Q-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/annie-spratt-hX_hf2lPpUU-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/annie-spratt-ncQ2sguVlgo-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/asoggetti-cfKC0UOZHJo-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/bradley-jasper-ybanez-a1xlQq3HoJ0-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/cole-keister-SG4fPCsywj4-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/david-gavi-AdIJ9S-kbrc-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/diego-ph-5LOhydOtTKU-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/drew-graham-cTKGZJTMJQU-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/frantisek-g-XXuVXLy5gHU-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/guille-pozzi-sbcIAn4Mn14-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/ivana-cajina-Hi0bdO0vEfo-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/joseph-pearson-3YxAZPyBPVw-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/kobu-agency-3hWg9QKl5k8-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/lea-l-q--99IzY8Lw-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/luke-chesser-3rWagdKBF7U-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/luke-chesser-PHtp0cDBJSM-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/mirza-babic-3vpqL4kJxX4-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/mymind-KG_BfyEgXhk-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pawel-czerwinski-6lQDFGOB1iw-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-andre-furtado-370717.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-anete-lusina-5240548.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-arthouse-studio-4534200.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-ave-calvar-martinez-4705114.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-cÃ¡tia-matos-1072179.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-carboxaldehyde-5786211.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-eva-elijas-5940376.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-gdtography-911738.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-gradienta-6985001.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-jeffrey-czum-2501965.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-johannes-plenio-1103970.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-kat-jayne-568025.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-mads-thomsen-2739013.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-matt-hardy-3560168.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-maxime-francis-2246476.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-noelle-otto-906018.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-oleg-magni-2033997.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-philippe-donn-1114690.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-photo-844297.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-pratik-gupta-2748716.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-sarah-chai-7262766.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-sharon-mccutcheon-3866851.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-stas-knop-5939401.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-tara-winstead-7722865.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-teona-swift-6912901.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-teona-swift-6913066.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/pexels-teona-swift-6913067.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/ricardo-gomez-angel-5YM26lUicfU-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/sawyer-bengtson-zisnY9gWr3Y-unsplash.jpg",
                               "https://tap-chat-media.s3.ap-southeast-1.amazonaws.com/chat-background/yusuf-evli-bVq6bh26H-Y-unsplash.jpg"]


enum FLDownloadImageState {
    case ready, downloading, downloaded, suppend
}

class FLDownloadImageObject: NSObject {
    var imgUrl = ""
    var localFileUrl = ""
    var localThumbFileUrl = ""
    var downloadTask:URLSessionDownloadTask?
    var completions = [FLAnyBlock]()
    
    var state:FLDownloadImageState = .ready {
        didSet {
            if state == .downloaded {
                print("Finish download \(imgUrl)")
                if let originImage = getOriginImage() {
                    let size = CGSize(width: WIDTH_SCREEN, height: HEIGHT_SCREEN)
                    let scaledImage = originImage.resizedImage(toFillPixelSize: size)
                    if let data = scaledImage.pngData() {
                        let thumbUrl = URL(fileURLWithPath: localThumbFileUrl)
                        try? data.write(to: thumbUrl)
                    }
                }
            }
            else if state == .downloading {
                print("Start download \(imgUrl)")
                downloadTask?.resume()
            }
            else if state == .suppend {
                print("Suppend download \(imgUrl)")
                downloadTask?.suspend()
            }
        }
    }
    
    func getOriginImage() -> UIImage? {
        let url = URL(fileURLWithPath: localFileUrl)
        if let imageData = try? Data(contentsOf: url),
           let ima = UIImage(data: imageData) {
            return ima
        }
        return nil
    }
    
    func getThumbImage() -> UIImage? {
        let url = URL(fileURLWithPath: localThumbFileUrl)
        if let imageData = try? Data(contentsOf: url),
           let ima = UIImage(data: imageData) {
            return ima
        }
        return nil
    }
}

class FLImageDownloader: NSObject {
    static let shared = FLImageDownloader()
    private var downloadTask = [FLDownloadImageObject]()
    let numberItemInQueue = 3
    
    func addWallPaper(wallPaper: FLDownloadImageObject, completion: FLAnyBlock?) {
        if let existedObj = self.downloadTask.first(where: { obj in
            return obj.localFileUrl == wallPaper.localFileUrl
        }) {
            if numberDownloading < numberItemInQueue {
                if existedObj.state != .downloading {
                    existedObj.state = .downloading
                    if completion != nil {
                        existedObj.completions.append(completion!)
                    }
                }
            }
            return
        }
        
        let tempFileURL = URL(fileURLWithPath: wallPaper.localFileUrl)
        let session = OWSSignalService.sharedInstance().cdnSessionManager(forCdnNumber: 0)
        
        var requestError: NSError?
        let request: NSMutableURLRequest = session.requestSerializer.request(withMethod: "GET",
                                                                             urlString: wallPaper.imgUrl,
                                                                             parameters: nil,
                                                                             error: &requestError)
        if let _ = requestError {
            return
        }
        
        let task = session.downloadTask(with: request as URLRequest,
                                        progress: { (progress) in
                                            print("Downloading progress \(progress.fractionCompleted)")
                                        },
                                        destination: { (_, _) -> URL in
                                            return tempFileURL
                                        },
                                        completionHandler: { (response, completionUrl, error) in
                                            if let completionUrl = completionUrl {
                                                if let idx = self.downloadTask.firstIndex(where: { wallPaper in
                                                    let localFileUrl = URL(fileURLWithPath: wallPaper.localFileUrl)
                                                    return completionUrl == localFileUrl
                                                }) {
                                                    let obj = self.downloadTask[idx]
                                                    obj.state = .downloaded
                                                    self.downloadTask.remove(at: idx)
                                                    
                                                    obj.completions.forEach { block in
                                                        block((obj, error))
                                                    }
                                                }
                                            }else {
                                                print("Download image fail with error \(error.debugDescription)")
                                                completion?((nil, error))
                                            }
                                            
                                            if self.numberDownloading < self.numberItemInQueue,
                                               let nextObj = self.findNextDownloadItem() {
                                                nextObj.state = .downloading
                                            }
                                        })
        wallPaper.downloadTask = task
        //        if downloadTask.count > 0 {
        //            downloadTask.insert(wallPaper, at: 1)
        //        }else {
        //            downloadTask.append(wallPaper)
        //        }
        downloadTask.append(wallPaper)
        
        if completion != nil {
            wallPaper.completions.append(completion!)
        }
        if numberDownloading < numberItemInQueue {
            wallPaper.state = .downloading
        }
    }
    
    func isDownloading(_ wallPaper: FLDownloadImageObject) -> Bool{
        if let _ = downloadTask.first(where: { obj in
            if obj.state == .downloading,
               wallPaper.imgUrl == obj.imgUrl {
                return true
            }
            return false
        }) {
            return true
        }
        return false
    }
 
    func findNextDownloadItem() -> FLDownloadImageObject? {
        for obj in downloadTask {
            if obj.state == .ready ||
                obj.state == .suppend {
                return obj
            }
        }
        print("No more item to download")
        return nil
    }
    
    
    func suppendAll() {
        for obj in downloadTask {
            if obj.state == .downloading{
                obj.state = .suppend
            }
        }
    }
    
    func removeAll() {
        suppendAll()
        downloadTask.removeAll()
    }
    
    var numberDownloading:Int {
        var val = 0
        for obj in downloadTask {
            if obj.state == .downloading {
                val += 1
            }
        }
        return val
    }
}


class FLChangeWallPaperVC: UIViewController {
    @IBOutlet weak var chooseFromPhotosBtn: UIButton!
    @IBOutlet weak var clv: UICollectionView!
    @IBOutlet weak var youshTemplateLbl: UILabel!
    var images = [Any]()
    var thread: TSThread?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        youshTemplateLbl.text = NSLocalizedString("YOUSH_TEMPLATES", comment: "")
        youshTemplateLbl.textColor = Theme.youshGoldColor
        // Do any additional setup after loading the view.
        chooseFromPhotosBtn.setTitle(FLLocalize("CHOOSE_FROM_PHOTOS"), for: .normal)
        navigationItem.leftBarButtonItem = UIViewController.createOWSBackButton(withTarget: self,
                                                                                selector: #selector(backButtonPressed))
        
        chooseFromPhotosBtn.border(radius: 3)
        clv.border(radius: 3)
        
        clv.backgroundColor = chooseFromPhotosBtn.backgroundColor
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        layout.sectionInset = UIEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        clv.collectionViewLayout = layout
        clv.dataSource = self
        clv.delegate = self
        
        var shouldShowRemoveWallPaperItem = false
        if let userDefaults = UserDefaults(suiteName: TSConstants.applicationGroup) {
            if let conthreadThread = thread as? TSContactThread,
               let phoneNumber = conthreadThread.contactPhoneNumber {
                let key = "CHAT_WALLPAPER_\(phoneNumber)"
                shouldShowRemoveWallPaperItem = userDefaults.value(forKey: key) != nil
            }
            
            else if let groupThread = thread as? TSGroupThread{
                let key = "CHAT_WALLPAPER_\(groupThread.uniqueId.replacingOccurrences(of: "/", with: ""))"
                shouldShowRemoveWallPaperItem = userDefaults.value(forKey: key) != nil
            }
        }
        if shouldShowRemoveWallPaperItem {
            images.append(Theme.backgroundColor)
        }
        
        if let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last  {
            let dataPath = cachesDirectoryURL.path + "/backgroundTemplates"
            if !FileManager.default.fileExists(atPath: dataPath) {
                do {
                    try FileManager.default.createDirectory(atPath: dataPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription)
                }
            }
            
            for str in IMAGES_TEMPLATE {
                if let imaUrl = URL(string: str) {
                    let obj = FLDownloadImageObject()
                    obj.imgUrl = str
                    let localFileUrl = dataPath + "/\(imaUrl.lastPathComponent)"
                    let localThumbFileUrl = dataPath + "/\(imaUrl.lastPathComponent)" + ".thumb"
                    obj.localFileUrl = localFileUrl
                    obj.localThumbFileUrl = localThumbFileUrl
                    images.append(obj)
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clv.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        clv.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        FLImageDownloader.shared.removeAll()
    }
    
    @IBAction func chooseFromPhotosBtnTouch(_ sender: Any) {
        if PHPhotoLibrary.authorizationStatus() == .notDetermined {
            PHPhotoLibrary.requestAuthorization { _ in
                DispatchQueue.main.async {
                    self.chooseFromPhotosBtnTouch(sender)
                }
            }
        }
        else if PHPhotoLibrary.authorizationStatus() == .authorized {
            let vc = ImagePickerGridController()
            vc.delegate = self
            let navController = SendMediaNavigationController()
            navController.modalPresentationStyle = .fullScreen
            navController.setViewControllers([vc], animated: false)
            present(navController, animated: true, completion: nil)
            navController.cameraModeButton.isHidden = true
        }
        else {
            if #available(iOS 14, *) {
                if PHPhotoLibrary.authorizationStatus() == .limited {
                    let vc = ImagePickerGridController()
                    vc.delegate = self
                    let navController = SendMediaNavigationController()
                    navController.modalPresentationStyle = .fullScreen
                    navController.setViewControllers([vc], animated: false)
                    present(navController, animated: true, completion: nil)
                    navController.cameraModeButton.isHidden = true
                }
            }
        }
            
    }
    
    @objc
    public func backButtonPressed(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}

extension FLChangeWallPaperVC: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FLSelectWallPaperCVC", for: indexPath) as! FLSelectWallPaperCVC
        cell.reload(images[indexPath.item])
        if let obj = images[indexPath.item] as? FLDownloadImageObject {
            if let ima = obj.getThumbImage() {
                cell.activity.stopAnimating()
                cell.img.image = ima
            }else {
                cell.activity.startAnimating()
                if FLImageDownloader.shared.isDownloading(obj) == false {
                    FLImageDownloader.shared.addWallPaper(wallPaper: obj) { [weak self] (result) in
                        guard let self = self,
                              self.view.window != nil else { return }
                        
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
        var width = Double(collectionView.frameWidth)
        width = (width - 30)/3
        width = floor(width)
        let height = width * 2
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = UIStoryboard.main.instantiateViewController(withIdentifier: FLPreviewWallPaperVC.classNameString) as! FLPreviewWallPaperVC
        vc.title = FLLocalize("PREVIEW_TITLE")
        vc.images = images
        vc.imageIndex = indexPath.item
        vc.thread = thread
        let nav = OWSNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let obj = images[indexPath.item] as? FLDownloadImageObject,
           obj.state == .downloading {
            obj.state = .suppend
        }
    }
}

extension FLChangeWallPaperVC: ImagePickerGridControllerDelegate {
    func imagePickerDidCompleteSelection(_ imagePicker: ImagePickerGridController) {
        
    }
    
    func imagePickerDidCancel(_ imagePicker: ImagePickerGridController) {
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    func imagePicker(_ imagePicker: ImagePickerGridController, isAssetSelected asset: PHAsset) -> Bool  {
        return false
    }
    
    func imagePicker(_ imagePicker: ImagePickerGridController, didSelectAsset asset: PHAsset, attachmentPromise: Promise<SignalAttachment>) {
        let imaIdx = imagePicker.photoCollectionContents.fetchResult.index(of: asset)
        var images = [PHAsset]()
        for i in 0...imagePicker.photoCollectionContents.fetchResult.count - 1 {
            let asset = imagePicker.photoCollectionContents.asset(at: i)
            images.append(asset)
        }
        let vc = UIStoryboard.main.instantiateViewController(withIdentifier: FLPreviewWallPaperVC.classNameString) as! FLPreviewWallPaperVC
        vc.title = FLLocalize("PREVIEW_TITLE")
        vc.images = images
        vc.thread = self.thread
        vc.imageIndex = imaIdx
        imagePicker.navigationController?.pushViewController(vc, animated: true)
    }
    
    func imagePicker(_ imagePicker: ImagePickerGridController, didDeselectAsset asset: PHAsset) {
        
    }
    
    var isInBatchSelectMode: Bool {
        return false
    }
    
    var isPickingAsDocument: Bool {
        return false
    }
    
    func imagePickerCanSelectMoreItems(_ imagePicker: ImagePickerGridController) -> Bool {
        return true
    }
    
    func imagePickerDidTryToSelectTooMany(_ imagePicker: ImagePickerGridController) {
        
    }
}

class FLSelectWallPaperCVC: UICollectionViewCell {
    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var activity: UIActivityIndicatorView!
    
    var tempFileURL: URL!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        img.backgroundColor = Theme.backgroundColor
    }
    
    func reload(_ ima: Any?) {
        activity.stopAnimating()
        img.image = nil
        
        if let imgName = ima as? String {
            img.image = UIImage(named: imgName)
        }
        else if let ima = ima as? UIImage {
            img.image = ima
        }
        else if let cl = ima as? UIColor {
            img.image = nil
            img.backgroundColor = cl
        }
        else if let asset = ima as? PHAsset {
            loadImage(asset: asset)
        }
    }
    
    private func loadImage(asset: PHAsset) {
        img.image = nil
        var ima: UIImage?
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        manager.requestImageData(for: asset, options: options) { data, _, _, _ in
            if let data = data {
                ima = UIImage(data: data)
            }
            self.img.image = ima
        }
    }
}
