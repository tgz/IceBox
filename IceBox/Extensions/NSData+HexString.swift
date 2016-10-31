//
//  NSData+HexString.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

extension NSData {

    /// NSData to String, <ab cd> -> "abcd"
    var hexString: String {
        return self.description.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>")).stringByReplacingOccurrencesOfString(" ", withString: "")
    }
}
