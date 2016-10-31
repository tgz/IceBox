//
//  Thermometer.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import CoreBluetooth
import Result

typealias DeviceSuscription = Result<NSData, DeviceError>

typealias DeviceSubscriptionClosure = (result: DeviceSuscription) -> Void
typealias DeviceResponseClosure = (result: Result<[NSData], DeviceError>) -> Void


final class TempBox: Linkable {
    let device: Device
    
    private var characteristicRead: CBCharacteristic?
    private var characteristicWrite: CBCharacteristic?
    private let UUID = TempBox.UUIDConstants()
    private let subscriptionEvent = Event<DeviceSuscription>()
    private var fetchCallback: DeviceSubscriptionClosure?
    private var fetchTimer: Timer?
    private(set) var isCommunicating = false
    private lazy var requestQueue: NSOperationQueue = {
        var queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    } ()
    private let communicationLockQueue = dispatch_queue_create("com.qsc.BLEQueue", DISPATCH_QUEUE_SERIAL)

    init(device: Device) {
        self.device = device
    }

    func toTarget() -> LinkTarget? {
        guard let name = device.name, mac = device.MAC else { return nil }
        return LinkTarget(MAC: mac, name: name)
    }

    deinit {
        log.verbose("")
        fetchTimer?.cancel()
        requestQueue.cancelAllOperations()
        if device.peripheral.state == .Connected {
            log.warning("Device not relinquish the connection")
        }
    }

    // MARK: - Subscription

    func startSubscription(callback: Device.ErrorClosure) {
        log.verbose("")
        if !isLinked {
            callback(error: .Disconnected)
            return
        }
        device.subscribe(characteristicRead!, callback: { (error) -> Void in
            if let error = error {
                log.warning("\(error)")
                callback(error: error)
                return
            }
            log.verbose("Subscribed!")
            callback(error: nil)
        }) { [weak self] (result) -> Void in
            guard let `self` = self else { return }
            self.consume(result)
        }
    }

    func subscribeXEvent(handler: DeviceSuscription -> () ) -> Disposable {
        log.verbose("")
        return subscriptionEvent.addHandler(handler)
    }

    // swiftlint:disable cyclomatic_complexity
    private func consume(subscription: Device.Value) {
        switch subscription {
        case let .Failure(error):
            log.warning("\(error)")
            if let callback = fetchCallback {
                fetchCallback = nil
                callback(result: .Failure(.SubscriptionConsumeError))
            }
        case let .Success(value):
            if let callback = fetchCallback {
                callback(result: .Success(value))
            }
        }
    }

    // MARK: - Fetch

    func fetchDataWithCommand(command: NSData, callback: DeviceResponseClosure) {
        log.verbose("\(command)")
        if !isLinked {
            callback(result: .Failure(.Disconnected))
            return
        }
        if characteristicRead!.isNotifying {
            self.writeThenFetch(command, callback: callback)
            return
        }
        log.verbose("Not notifying, start subcription first.")
        self.startSubscription({ [weak self] (error) -> Void in
            guard let `self` = self else { return }
            if let _ = error {
                callback(result: .Failure(.SubscribeFailed))
                return
            }
            self.writeThenFetch(command, callback: callback)
            })
    }

    private func writeThenFetch(value: NSData, callback: DeviceResponseClosure) {
        log.verbose(value)
        if isCommunicating == true {
            callback(result: .Failure(.Busy))
            return
        }
        dispatch_sync(communicationLockQueue) { () -> Void in
            self.isCommunicating = true
        }
        device.write(value, forCharacteristic: characteristicWrite!) { [weak self] (error) -> Void in
            guard let `self` = self else { return }
            if let error = error {
                log.error(error)
                dispatch_sync(self.communicationLockQueue) { () -> Void in
                    self.isCommunicating = false
                }
                callback(result: .Failure(.WriteFailed))
                return
            }
            var values = [NSData]()

            func setupTimer(time: NSTimeInterval = 1.5) {
                self.fetchTimer = Timer.after(time, queue: defaultHaraldCentralQueue, block: { () -> Void in
                    log.verbose("Fetch done by timer, got \(values.count) data")
                    self.fetchTimer = nil
                    self.fetchCallback = nil
                    dispatch_sync(self.communicationLockQueue) { () -> Void in
                        self.isCommunicating = false
                    }
                    if values.count > 0 {
                        callback(result: .Success(values))
                    } else {
                        callback(result: .Failure(.FetchTimeout))
                    }
                })
            }
//            setupTimer(8)
            self.fetchCallback = { (result) -> Void in
                self.fetchTimer?.cancel()
                self.fetchTimer = nil
                switch result {
                case let .Failure(error):
                    log.warning("\(error)")
                    self.fetchCallback = nil
                    dispatch_sync(self.communicationLockQueue) { () -> Void in
                        self.isCommunicating = false
                    }
                    callback(result: .Failure(error))
                case let .Success(value):
                    if value.length == 3 {
                        let bytes = UnsafePointer<UInt8>(value.bytes)
                        if bytes[0] == 0xaa && bytes[2] == 0x01 {
                            log.verbose("Fetch done by flag, got \(values.count) data.")
                            self.fetchCallback = nil
                            dispatch_sync(self.communicationLockQueue) { () -> Void in
                                self.isCommunicating = false
                            }
                            callback(result: .Success(values))
                            return
                        }
                    }
                    values.append(value)
                    if values.count == 5 {
                        log.verbose("Fetch done by max frame count (5) data.")
                        self.fetchCallback = nil
                        dispatch_sync(self.communicationLockQueue) { () -> Void in
                            self.isCommunicating = false
                        }
                        callback(result: .Success(values))
                        return
                    }
                    setupTimer()
                }
            }
        }
    }

    // MARK: - Command

    func sendCommand(value: NSData, callback: DeviceResponseClosure) {
        log.verbose(value)
        if !isLinked {
            callback(result: .Failure(.Disconnected))
            return
        }
        if isCommunicating {
            callback(result: .Failure(.Busy))
            return
        }
        dispatch_sync(self.communicationLockQueue) { () -> Void in
            self.isCommunicating = true
        }
        device.write(value, forCharacteristic: characteristicWrite!) { [weak self] (error) -> Void in
            guard let `self` = self else { return }
            dispatch_sync(self.communicationLockQueue) { () -> Void in
                self.isCommunicating = false
            }
            if let error = error {
                callback(result: .Failure(error))
            } else {
                callback(result: .Success([]))
            }
        }
    }

    // MARK: - Linkable

    var target: Device {
        return device
    }

    var isLinked: Bool {
        return isConnected && characteristicRead != nil && characteristicWrite != nil
    }

    func link(callback: Device.ErrorClosure) {
        log.verbose("")
        if isLinked {
            callback(error: nil)
            return
        }
        device.link([UUID.service128Bits: [UUID.characteristicRead, UUID.characteristicWrite]]) { [weak self] (error) -> Void in
            guard let strongSelf = self else {
                log.warning("Nil self.")
                return
            }

            if let error = error {
                log.warning("\(error)")
                callback(error: error)
                return
            }

            guard let characteristicRead = strongSelf.device.characteristicByUUID(strongSelf.UUID.characteristicRead) else {
                log.warning("Nil characteristicRead!")
                callback(error: .CharacteristicNotFound)
                return
            }

            guard let characteristicWrite = strongSelf.device.characteristicByUUID(strongSelf.UUID.characteristicWrite) else {
                log.warning("Nil characteristicWrite!")
                callback(error: .CharacteristicNotFound)
                return
            }

            strongSelf.characteristicWrite = characteristicWrite
            strongSelf.characteristicRead = characteristicRead

            strongSelf.startSubscription({ (error) -> Void in
                if let error = error {
                    log.error(error)
                }
            })

            callback(error: nil)
        }
    }
}

extension TempBox {
    struct UUIDConstants {
//        let service16Bits = CBUUID(string: "0001")
//        let service128Bits = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca1e")
//
//        let characteristicRead = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca1e")
//        let characteristicWrite = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca1e")
        let service16Bits = CBUUID(string: "0729")
        let service128Bits = CBUUID(string: "6e400729-b5a3-f393-e0a9-e50e24dcca9e")
        let characteristicRead = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
        let characteristicWrite = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    }
}
