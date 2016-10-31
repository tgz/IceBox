//
//  Bool+Convience.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

extension Bool {
    var intValue: Int {
        return self ? 1 : 0
    }
    var uInt8Value: UInt8 {
        return UInt8(intValue)
    }
    func flip() -> Bool {
        return !self
    }
}
