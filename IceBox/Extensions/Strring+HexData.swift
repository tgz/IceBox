//
//  Strring+HexData.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

extension String {

    /// String to NSData, "20 01" -> <2001>, "2001" -> <2001>
    var hexData: NSData? {
        let strWithoutSpace = self.stringByReplacingOccurrencesOfString(" ", withString: "", options: [], range: nil)
        return NSData(hexString: strWithoutSpace)
    }
}
