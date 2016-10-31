//
//  NSErrorConvertible.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

protocol NSErrorConvertible: ErrorType {
    var domain: String { get }
    var reason: String { get }

    var rawValue: Int { get }
    var error: NSError { get }
}

extension NSErrorConvertible {
    var reason: String {
        return "\(self)"
    }

    var error: NSError {
        return NSError(domain: self.domain, code: self.rawValue, userInfo: [NSLocalizedFailureReasonErrorKey: self.reason])
    }
}