//
//  DeviceError.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

enum DeviceError: Int, NSErrorConvertible {
    case Busy
    case HaraldNil
    case AlreadyConnecting
    case ConnectionFailed
    case Disconnected
    case DisconectedUnexpectedly
    case DiscoverTimeout
    case ServiceNotFound
    case CharacteristicNotFound
    case WriteValueFailed
    case IsAlreadySubscribed
    case SubscribeFailed
    case UpdateValueFailed
    case RSSIReadFailed

    case SubscriptionConsumeError
    case SubscritionIntercepted
    case CommandError
    case WriteFailed
    case FetchTimeout
    case Unknown

    // MARK: - NSErrorConvertible

    var domain: String {
        return "DeviceErrorDomain"
    }
}
