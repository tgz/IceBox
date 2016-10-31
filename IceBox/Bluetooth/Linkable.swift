//
//  Linkable.swift
//  IceBox
//
//  Created by QSC on 16/7/9.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

protocol Linkable {
    var target: Device { get }
    var isConnected: Bool { get }
    var isLinked: Bool { get }

    func link(callback: Device.ErrorClosure)
    func unlink(callback: Device.ErrorClosure)
}

extension Linkable {
    var isConnected: Bool {
        return target.peripheral.state == .Connected
    }

    func unlink(callback: Device.ErrorClosure) {
        log.verbose()
        target.unlink(callback)
    }
}
