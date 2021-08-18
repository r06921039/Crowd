//
//  HorizontalCell.swift
//  Crowd
//
//  Created by Jeff on 2021/3/1.
//

import UIKit

struct HorizontalCellViewModel {
    let image: UIImage?
    let title: String
}

class HorizontalCell: UICollectionViewCell {
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var lbl: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        button.layer.cornerRadius = button.frame.height/2
        button.layer.masksToBounds = true
    }
    
    func configure(with model: HorizontalCellViewModel){
        button.setImage(model.image, for: .normal)
        lbl.text = model.title
    }
}
