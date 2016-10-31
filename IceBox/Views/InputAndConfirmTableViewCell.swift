//
//  InputAndConfirmTableViewCell.swift
//  IceBox
//
//  Created by QSC on 16/7/16.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit

class InputAndConfirmTableViewCell: UITableViewCell {
    @IBOutlet var input: UITextField!
    @IBOutlet var button: UIButton!

    @IBOutlet var titleLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
