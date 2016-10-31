//
//  ScanResultTableViewCell.swift
//  IceBox
//
//  Created by QSC on 16/7/30.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit

class ScanResultTableViewCell: UITableViewCell {
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var rssiLabel: UILabel!
    @IBOutlet var addressLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func setDevice(device: Device) {
        nameLabel.text = device.name ?? "--"
        rssiLabel.text = "\(device.RSSI?.stringValue ?? "--") dBm"
        addressLabel.text = device.MAC ?? ""
    }
    
}
