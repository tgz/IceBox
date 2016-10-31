//
//  BLEAPI.swift
//  BLE
//
//  Created by QSC on 16/7/9.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

enum BLEAPI {
    case Reset
    case SetTime(date: NSDate)
    case Rename(name: String)
    case SetSamplingInterval(interval: Int)
    case FetchTempData
    case FetchSamplingInterval
    case WipeData
    case SendACK(type: ACK, success: Bool)
}

extension BLEAPI {
    func shouldResponse() -> Bool {
        switch self {
        case .SetTime(_), .Rename(_), .SetSamplingInterval(_), .FetchTempData, .FetchSamplingInterval, .WipeData:
            return true
        default:
            return false
        }
    }

    func commandValue() -> NSData? {
        switch self {
        case .Reset:
            return "55 01 00 00".hexData
        case .SetTime(let date):
            return String("55 02 \(date.hexString()) 00 00").hexData
        case .Rename(let name):
            if let nameHex = name.hexString() {
                return "55 03 \(nameHex) 00 00".hexData
            }
            return nil
        case .SetSamplingInterval(let interval):
            return String(format: "55 04 %02x 00 00", interval).hexData
        case .FetchTempData:
            return "55 05 00 00".hexData
        case .FetchSamplingInterval:
            return "55 06 00 00".hexData
        case .WipeData:
            return "55 07 00 00".hexData
        case let .SendACK(type, success):
            return String(format: "aa %02x %02x", type.rawValue, success.uInt8Value).hexData
        }
    }
}

enum ACK: UInt8 {
    case Reset = 1
    case SetTime = 2
    case Rename = 3
    case SetSamplingInterval = 4
    case FetchTempData = 5
    case FetchSamplingInterval = 6
    case WipeData = 7
}


extension TempBox {
    func requestByAPI(API: BLEAPI, callback: DeviceResponseClosure) {
        guard let value = API.commandValue() else {
            callback(result: .Failure(.CommandError))
            return
        }
        if API.shouldResponse() {
            fetchDataWithCommand(value, callback: callback)
        } else {
            sendCommand(value, callback: callback)
        }
    }
}

extension NSDate {
    func stringwithForamt(format: String) -> String {
        let dataFormat = NSDateFormatter()
        dataFormat.dateFormat = format
        return dataFormat.stringFromDate(self)
    }

    /**
     转换成十六进制形式日期字符串，用于同步时间

     - returns: yy MM dd HH mm 的十六进制字符串
     */

    func hexString() -> String {
        let components = NSCalendar.currentCalendar().components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: self)
        //UInt16(bigEndian: UInt16(
        return String(format: "%04x%02x%02x%02x%02x%02x", components.year, components.month, components.day, components.hour, components.minute, components.second)
    }
}

extension String {
    func hexString() -> String? {
        return self.dataUsingEncoding(NSUTF8StringEncoding)?.hexString
    }
}
