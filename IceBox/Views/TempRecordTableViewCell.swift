//
//  TempRecordTableViewCell.swift
//  IceBox
//
//  Created by QSC on 16/7/31.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit

class TempRecordTableViewCell: UITableViewCell {

    @IBOutlet var tempLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setTemperaure(temp: Temperature) {
        self.tempLabel.text = String(format: "%.2f", temp.temp)
        self.timeLabel.text = temp.date.stringwithForamt("HH:mm:ss")
    }
    
}
