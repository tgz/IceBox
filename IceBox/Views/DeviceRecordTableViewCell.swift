//
//  DeviceRecordTableViewCell.swift
//  IceBox
//
//  Created by QSC on 16/7/31.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit

class DeviceRecordTableViewCell: UITableViewCell {
    @IBOutlet var addressLabel: UILabel!
    @IBOutlet var lastLinkDateLabel: UILabel!
    @IBOutlet var nameLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setHistory(history: DeviceHistory) {
        self.nameLabel.text = history.name
        self.lastLinkDateLabel.text = history.date.stringwithForamt("yyyy-MM-dd")
        self.addressLabel.text = history.MAC
    }

}
