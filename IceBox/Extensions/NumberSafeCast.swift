//
//  NumberSafeCast.swift
//  IceBox
//
//  Created by QSC on 16/7/10.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

extension Int8 {
    func toUInt8() -> UInt8 {
        return UInt8(Swift.max(0, self))
    }
}

extension UInt8 {
    func toInt16() -> Int16 {
        return Int16(self)
    }

    func toInt32() -> Int32 {
        return Int32(self)
    }

    func toUInt16() -> UInt16 {
        return UInt16(self)
    }
}

extension Int16 {
    func toUInt16() -> UInt16 {
        return UInt16(Swift.max(0, self))
    }

    func toUInt32() -> UInt32 {
        return UInt32(Swift.max(0, self))
    }

    func toInt32() -> Int32 {
        return Int32(self)
    }

    func toUInt8() -> UInt8 {
        return UInt8(Swift.max(0, Swift.min(Int16(UInt8.max), self)))
    }
}

extension UInt16 {
    func toInt16() -> Int16 {
        return Int16(self)
    }
    func toInt32() -> Int32 {
        return Int32(self)
    }
}

extension Int32 {
    func toUInt32() -> UInt32 {
        return UInt32(Swift.max(0, self))
    }

    func toInt64() -> Int64 {
        return Int64(self)
    }
}

extension UInt32 {
    func toInt64() -> Int64 {
        return Int64(self)
    }

    func toInt16() -> Int16 {
        return Int16(Swift.max(0, Swift.min(UInt32(Int16.max), self)))
    }
}

extension Int64 {
    func toNSTimeInterval() -> NSTimeInterval {
        return NSTimeInterval(self)
    }

    func toUInt32() -> UInt32 {
        return UInt32(Swift.min(Int64(UInt32.max), Swift.max(0, self)))
    }
}

extension NSTimeInterval {
    func toInt64() -> Int64 {
        return Int64(Swift.min(NSTimeInterval(Int64.max), self))
    }
}
