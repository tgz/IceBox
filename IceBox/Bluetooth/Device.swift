//
//  Device.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//


import CoreBluetooth
import Result

class Device: NSObject {
    typealias ErrorClosure = (error: DeviceError?) -> Void
    typealias Value = Result<NSData, DeviceError>
    typealias ValueClosure = (result: Value) -> Void

    typealias ServiceUUID = CBUUID
    typealias CharacteristicUUID = CBUUID

    static let defaultTimeout = 0.0

    let peripheral: CBPeripheral
    var RSSI: NSNumber?
    var advertisementData: [String : AnyObject]?
    var name: String? { return peripheral.name }
    var disconnectionEvent = Event<DeviceError?>()

    private weak var harald: Harald?
    private var isLinking = false
    private var serviceAndCharacteristicUUIDs: [ServiceUUID: [CharacteristicUUID]]?
    private var servicesDiscovered: [CBService]?
    private var characteristicsDiscovered: [CBCharacteristic]?
    private var connectCallback: ErrorClosure?
    private var connectTimer: Timer?
    private var disconnectCallback: ErrorClosure?
    private var discoverCallback: ErrorClosure?
    private var discoverTimer: Timer?
    private var writeCallback: ErrorClosure?
    private var subscribeCallback: ErrorClosure?
    var updateCallback: ValueClosure?
    private var RSSICallback: ((Result<NSNumber, DeviceError>) -> Void)?

    // MARK: - Life cycle

    init(harald: Harald, peripheral: CBPeripheral, advertisementData: [String : AnyObject]? = nil, RSSI: NSNumber? = nil) {
        self.harald = harald
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.RSSI = RSSI

        super.init()
        self.peripheral.delegate = self
    }

    deinit {
        connectTimer?.cancel()
        discoverTimer?.cancel()
    }

    // MARK: - CustomStringConvertible

    override var description: String {
        return "\nperiphera: \(peripheral)\nRSSI: \(RSSI)\nadvertisementData: \(advertisementData)\nharald: \(harald)"
    }

    // MARK: - Hashable

    override var hashValue: Int {
        return peripheral.hashValue
    }

    // MARK: - Link & Unlink

    func link(UUIDs: [ServiceUUID: [CharacteristicUUID]]?, timeout: NSTimeInterval = Device.defaultTimeout, callback: ErrorClosure) {
        if isLinking {
            log.warning("Alreading linking")
            callback(error: .AlreadyConnecting)
            return
        }
        isLinking = false

        self.connect(timeout) { [weak self] (error) -> Void in
            guard let strongSelf = self else {
                log.warning("Nil self.")
                return
            }

            if let err = error {
                log.warning(err)
                strongSelf.isLinking = false
                callback(error: err)
                return
            }

            log.verbose("Discovering...")
            strongSelf.discoverServicesAndCharacteristics(UUIDs, timeout: timeout, callback: { (error) -> Void in
                if let err = error {
                    log.warning(err)
                    strongSelf.isLinking = false
                    callback(error: err)
                    return
                }

                log.verbose("Discovered!")
                strongSelf.isLinking = false
                callback(error: nil)
            })
        }
    }

    func finishDiscover() {
        discoverCallback = nil
        discoverTimer?.cancel()
        discoverTimer = nil
    }

    func unlink(callback: ErrorClosure?) {
        log.verbose("")
        self.disconnect(callback)
    }

    func readRSSI(callback: (Result<NSNumber, DeviceError>) -> Void) {
        if peripheral.state != .Connected {
            callback(.Failure(.Disconnected))
            return
        }
        RSSICallback = callback
        peripheral.readRSSI()
    }


    // MARK: - Characteristic

    func characteristicByUUID(UUID: CBUUID) -> CBCharacteristic? {
        guard let characteristics = characteristicsDiscovered else { return nil }
        for characteristic in characteristics {
            if characteristic.UUID == UUID {
                return characteristic
            }
        }
        return nil
    }

    func write(data: NSData, forCharacteristic characteristic: CBCharacteristic, callback: ErrorClosure?) {
        log.verbose(data)
        if peripheral.state != CBPeripheralState.Connected {
            log.warning("Not connected!")
            if let callback = callback { callback(error: .Disconnected) }
            return
        }

        writeCallback = callback
        peripheral.writeValue(data, forCharacteristic: characteristic, type: callback == nil ? .WithoutResponse : .WithResponse)
    }

    func subscribe(characteristic: CBCharacteristic, callback: ErrorClosure, update: ValueClosure) {
        if characteristic.isNotifying {
            log.verbose("isNotifying")
            callback(error: nil)
            return
        }

        subscribeCallback = callback
        updateCallback = update
        peripheral.setNotifyValue(true, forCharacteristic: characteristic)
    }

    func unsubscribe(characteristic: CBCharacteristic, callback: ErrorClosure?) {
        if !characteristic.isNotifying {
            log.verbose("Already unsubscribed.")
            if let callback = callback {
                callback(error: nil)
            }
            return
        }

        subscribeCallback = callback
        updateCallback = nil
        peripheral.setNotifyValue(false, forCharacteristic: characteristic)
    }

    // MARK: - Connect

    private func connect(timeout: NSTimeInterval = Device.defaultTimeout, callback: Device.ErrorClosure) {
        log.verbose()
        if peripheral.state == CBPeripheralState.Connecting {
            log.warning("AlreadyConnecting")
            callback(error: .AlreadyConnecting)
            return
        }
        if peripheral.state == CBPeripheralState.Connected {
            log.warning("Already connected")
            callback(error: nil)
            return
        }
        guard let harald = harald else {
            log.warning("Harald nil")
            callback(error: .HaraldNil)
            return
        }
        if timeout > 0.0 {
            connectTimer = Timer.after(timeout, queue: defaultHaraldCentralQueue, block: { () -> Void in
                log.warning("Connection timeout.")
                self.connectTimer = nil
                self.disconnect({ [weak self] (error) -> Void in
                    self?.connectCallback = nil
                    callback(error: .ConnectionFailed)
                    })
            })
        }
        log.verbose("Connecting...")
        connectCallback = callback
        harald.connect(self)
    }

    func handleConnection(error: DeviceError?) {
        log.verbose("")
        connectTimer?.cancel()
        connectTimer = nil

        guard let callback = connectCallback else {
            log.warning("connectCallback nil")
            if let discoverClosure = discoverCallback {
                discoverCallback = nil
                discoverClosure(error: .ConnectionFailed)
            }
            return
        }

        connectCallback = nil
        callback(error: error)
    }

    // MARK: - Disconnect

    private func disconnect(callback: ErrorClosure?) {
        log.verbose("")
        connectTimer?.cancel()
        connectTimer = nil

        if peripheral.state == .Disconnected {
            if let callback = callback {
                callback(error: nil)
            }
            return
        }

        guard let harald = harald else {
            if let callback = callback {
                callback(error: .HaraldNil)
            }
            return
        }
        disconnectCallback = callback
        harald.cancelConnect(self)
    }

    func handleDisconnection(error: DeviceError?) {
        log.debug("")
        if let callback = disconnectCallback {
            log.debug("disconnect callback")
            cleanup()
            callback(error: error)
            return
        } else if let callback = connectCallback {
            log.debug("connect callback")
            cleanup()
            callback(error: error)
            return
        } else if let callback = discoverCallback {
            log.debug("discover callback")
            cleanup()
            callback(error: error)
            return
        } else if let callback = writeCallback {
            log.debug("write callback")
            cleanup()
            callback(error: error)
            return
        }
        log.debug("disconnection event")
        cleanup()
        disconnectionEvent.raise(error)
    }

    private func cleanup() {
        log.verbose()
        serviceAndCharacteristicUUIDs = nil
        servicesDiscovered = nil
        characteristicsDiscovered = nil
        discoverCallback = nil
        discoverTimer?.cancel()
        discoverTimer = nil
        writeCallback = nil
        subscribeCallback = nil
        updateCallback = nil
        disconnectCallback = nil
        connectCallback = nil
    }

    // MARK: - Discover

    private func discoverServicesAndCharacteristics(UUIDs: [ServiceUUID: [CharacteristicUUID]]?, timeout: NSTimeInterval = Device.defaultTimeout, callback: Device.ErrorClosure) {
        if peripheral.state != .Connected {
            log.verbose("\(peripheral.state)")
            return
        }
        serviceAndCharacteristicUUIDs = UUIDs
        discoverCallback = callback
        servicesDiscovered = nil
        characteristicsDiscovered = nil
        if timeout > 0.0 && UUIDs != nil {
            discoverTimer = Timer.after(timeout, queue: defaultHaraldCentralQueue, block: { () -> Void in
                log.warning("Discover timeout.")
                self.discoverTimer = nil
                guard let callback = self.discoverCallback else {
                    log.verbose("Callback nil")
                    return
                }
                self.discoverCallback = nil
                callback(error: .DiscoverTimeout)
            })
        }
        var serviceUUIDs: [ServiceUUID]?
        if let map = UUIDs {
            serviceUUIDs = Array(map.keys)
        }
        self.peripheral.discoverServices(serviceUUIDs)
    }
}

extension Device: CBPeripheralDelegate {
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        log.verbose()
        guard let services = self.peripheral.services else {
            self.discoverTimer?.cancel()
            self.discoverTimer = nil

            if let callback = self.discoverCallback {
                self.discoverCallback = nil
                callback(error: .ServiceNotFound)
            }
            return
        }

        servicesDiscovered = services
        for service in services {
            var characteristicUUIDs: [CBUUID]?
            if let UUIDs = self.serviceAndCharacteristicUUIDs {
                characteristicUUIDs = UUIDs[service.UUID]
            }
            self.peripheral.discoverCharacteristics(characteristicUUIDs, forService: service)
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        log.verbose()
        func callbackByError(error: DeviceError?) {
            discoverTimer?.cancel()
            discoverTimer = nil
            if let callback = discoverCallback {
                discoverCallback = nil
                callback(error: error)
            }
        }
        guard let characteristics = service.characteristics where error == nil else {
            if let _ = error { log.warning("\(error)") }
            callbackByError(.CharacteristicNotFound)
            return
        }

        if characteristicsDiscovered == nil { characteristicsDiscovered = [CBCharacteristic]() }
        characteristicsDiscovered!.appendContentsOf(characteristics)
        if let UUIDs = serviceAndCharacteristicUUIDs {
            var allUUIDs = Set<CBUUID>()
            for key in UUIDs.keys {
                allUUIDs = allUUIDs.union(UUIDs[key]!)
            }
            var UUIDsFound = Set<CBUUID>()
            for c in characteristicsDiscovered! {
                UUIDsFound.insert(c.UUID)
            }
            let UUIDsMissed = allUUIDs.subtract(UUIDsFound)
            if UUIDsMissed.count == 0 {
                callbackByError(nil)
            }
        } else if let callback = discoverCallback {
            callback(error: nil)
        }
    }

    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard let callback = writeCallback else {
            log.warning("Nil callback")
            return
        }

        writeCallback = nil
        callback(error: error == nil ? nil : .WriteValueFailed)
    }

    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard let callback = subscribeCallback else {
            log.warning("Nil callback")
            return
        }
        subscribeCallback = nil
        callback(error: error == nil ? nil : .SubscribeFailed)
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        guard let callback = updateCallback else {
            log.warning("Nil callback")
            return
        }

        let value = characteristic.value
        log.verbose(value)
        callback(result: value == nil ? .Failure(.UpdateValueFailed) : .Success(value!))
    }

    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        log.verbose(RSSI)
        if let callback = RSSICallback {
            RSSICallback = nil
            if let error = error {
                log.error(error)
                callback(.Failure(.RSSIReadFailed))
                return
            }
            self.RSSI = RSSI
            callback(.Success(RSSI))
        }
    }

    func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
        log.verbose()

    }
}

extension Device {
    var MAC: String? {
        guard let advertisementData = advertisementData, let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData where  manufacturerData.length >= 8 else {
            return nil
        }
        var identifier = String()
        let bytes = UnsafePointer<UInt8>(manufacturerData.bytes)
        for index in 7.stride(through: 2, by: -1) {
            identifier = identifier.stringByAppendingFormat("%02x", bytes[index])
        }
        return identifier.uppercaseString
    }
}
