//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import UIKit

class FLBaseCVC: UICollectionViewCell {
    var model:Any?
    var ip:IndexPath?
//    var transaction:SDSAnyReadTransaction!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        prepareForReuse()
    }
    
    static var cellId: String {
        return String(describing: self.self)
    }
    
    static  var cellNib: UINib {
        return UINib(nibName: self.cellId, bundle: nil)
    }
    
    class func cellSize(_ clv: UICollectionView?, _ model: Any?) -> CGSize {
        return CGSize(width: 100, height: 100)
    }
}
