//
//  Result+Check.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation
import Result

extension Result {
    /// Returns `true` if the result is a success, `false` otherwise.
    public var isSuccess: Bool {
        switch self {
        case .Success:
            return true
        case .Failure:
            return false
        }
    }

    /// Returns `true` if the result is a failure, `false` otherwise.
    public var isFailure: Bool {
        return !isSuccess
    }
}
