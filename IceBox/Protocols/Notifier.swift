//
//  Notifier.swift
//  IceBox
//
//  Created by QSC on 16/7/9.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

protocol Notifier {
    associatedtype Notification: RawRepresentable
}

extension Notifier where Notification.RawValue == String {
    private static func nameFor(notification: Notification) -> String {
        return "\(self).\(notification.rawValue)"
    }

    func postNotification(notification: Notification, object: AnyObject? = nil, userInfo: [String: AnyObject]? = nil) {
        Self.postNotification(notification, object: object, userInfo: userInfo)
    }

    static func postNotification(notification: Notification, object: AnyObject? = nil, userInfo: [String: AnyObject]? = nil) {
        let name = nameFor(notification)
        NSNotificationCenter.defaultCenter()
            .postNotificationName(name, object: object, userInfo: userInfo)
    }

    static func addObserver(observer: AnyObject, selector: Selector, notification: Notification) {
        let name = nameFor(notification)
        NSNotificationCenter.defaultCenter()
            .addObserver(observer, selector: selector, name: name, object: nil)
    }

    static func removeObserver(observer: AnyObject, notification: Notification, object: AnyObject? = nil) {
        let name = nameFor(notification)
        NSNotificationCenter.defaultCenter()
            .removeObserver(observer, name: name, object: object)
    }
}
