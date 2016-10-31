//
//  NSData+Bytes.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

extension NSData {
    func toBytes() -> [UInt8] {
        let pointer = UnsafePointer<UInt8>(self.bytes)
        let bufferPointer = UnsafeBufferPointer<UInt8>(start: pointer, count: self.length)
        return [UInt8](bufferPointer)
    }
}
