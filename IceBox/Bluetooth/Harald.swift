//
//  Harald.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import CoreBluetooth
import Result

let defaultHaraldCentralQueue = dispatch_queue_create("HaralDefaultCentralManagerQueue", nil)
private let defaultCentralOptions = [CBCentralManagerOptionShowPowerAlertKey: false]


class Harald: NSObject {
    let central: CBCentralManager

    typealias ErrorClosure = (error: Error?) -> Void
    typealias ScanClosure = (result: Result<Device, Error>) -> Void

    var scanning: Bool {
        return isScanning
    }

    private var launchCallback: ErrorClosure?
    private var scanCallback: ScanClosure?
    private var connectCallback: Device.ErrorClosure?

    private var isScanning = false
    private var scanTimer: Timer?

    private var deviceConnecting = [CBPeripheral: Device]()
    private var discoveredDevices = [Device]()

    private let stateEvent = Event<CBCentralManagerState>()
    private var centralQueue: dispatch_queue_t?

    init(queue: dispatch_queue_t? = defaultHaraldCentralQueue, options: [String: AnyObject]? = defaultCentralOptions, launch: ErrorClosure? = nil) {
        log.verbose("")

        central = CBCentralManager(delegate: nil, queue: queue, options: options)
        super.init()

        centralQueue = queue
        launchCallback = launch
        central.delegate = self
    }

    deinit {
        log.verbose("")
    }

    // MARK: - State subscribe

    func subscribeState(handler: (state: CBCentralManagerState) -> Void) -> Disposable {
        return stateEvent.addHandler(handler)
    }

    // MARK: - Scan

    func scanPeripherals(byServices services: [CBUUID]? = nil, names: [String]? = nil, timeout: NSTimeInterval? = nil, duplicate: Bool = false, callback: ScanClosure) {
        log.verbose("")

        if !central.isPoweredOn() {
            log.verbose("\(central.state)")
            callback(result: .Failure(.NotPoweredOn))
            return
        }
        if isScanning {
            return
        }
        isScanning = true
        clean()
        if let time = timeout {
            scanTimer?.cancel()
            scanTimer = Timer.after(time, queue: callbackQueue(), block: { () -> Void in
                log.verbose("scan timeout")
                self.scanTimer = nil
                self.stopScan()
                dispatch_async(self.callbackQueue(), { () -> Void in
                    callback(result: .Failure(.Timeout))
                })
            })
        }
        scanCallback = { (result) -> Void in
            if let deviceName = result.value?.name, filterNames = names where filterNames.isEmpty == false {
                if filterNames.contains(deviceName) == false {
                    return
                }
            }
            callback(result: result)
        }
        central.scanForPeripheralsWithServices(services, options: [CBCentralManagerScanOptionAllowDuplicatesKey : duplicate])
    }

    func stopScan() {
        log.verbose("")
        scanCallback = nil
        central.stopScan()
        scanTimer?.cancel()
        scanTimer = nil
        isScanning = false
    }

    func clean() {
        discoveredDevices.removeAll()
    }

    // MARK: - Rtrieve

    func retrieveDevicesWithIdentifiers(identifiers: [NSUUID]) -> [Device] {
        log.verbose("identifiers: \(identifiers)")

        let peripherals = self.central.retrievePeripheralsWithIdentifiers(identifiers)
        var devices = [Device]()
        for peripheral in peripherals {
            var targetDevice: Device?
            for device in self.discoveredDevices {
                if device.peripheral == peripheral {
                    targetDevice = device
                    break
                }
            }
            if targetDevice == nil {
                targetDevice = Device(harald: self, peripheral: peripheral)
                discoveredDevices.append(targetDevice!)
            }
            devices.append(targetDevice!)
        }
        return devices
    }

    func retrieveConnectedDevices(byServiceUUIDs UUIDs: [CBUUID], name: String? = nil) -> [Device] {
        log.verbose("servicesUUIDs: \(UUIDs)")
        let peripherals = self.central.retrieveConnectedPeripheralsWithServices(UUIDs)
        var devices = [Device]()
        for peripheral in peripherals {
            var targetDevice: Device?
            for device in self.discoveredDevices {
                if device.peripheral == peripheral {
                    targetDevice = device
                    break
                }
            }
            if targetDevice == nil {
                if let n = name where peripheral.name != n {
                    continue
                }
                targetDevice = Device(harald: self, peripheral: peripheral)
                discoveredDevices.append(targetDevice!)
            } else if let n = name where peripheral != n {
                continue
            }
            devices.append(targetDevice!)
        }
        return devices
    }

    // MARK: - Connect

    func connect(device: Device) {
        log.verbose("")
        if deviceConnecting[device.peripheral] != device {
            deviceConnecting[device.peripheral] = device
        }

        if device.peripheral.state == .Connected {
            device.handleConnection(nil)
            return
        }

        self.central.connectPeripheral(device.peripheral, options: nil)
    }

    func cancelConnect(device: Device) {
        log.verbose("")
        if deviceConnecting[device.peripheral] == nil {
            log.warning("Not found in connecting list.")
        }

        if device.peripheral.state == .Disconnected {
            device.handleDisconnection(nil)
            return
        }

        self.central.cancelPeripheralConnection(device.peripheral)
    }

    private func callbackQueue() -> dispatch_queue_t {
        return centralQueue ?? dispatch_get_main_queue()
    }
}

// MARK: - CBCentralManagerDelegate

extension Harald: CBCentralManagerDelegate {
    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        log.verbose("dict: \(dict)")
    }

    func centralManagerDidUpdateState(central: CBCentralManager) {
        self.stateEvent.raise(central.state)

        guard let callback = self.launchCallback else {
            return
        }

        self.launchCallback = nil
        if central.state == CBCentralManagerState.PoweredOn {
            callback(error: nil)
        } else {
            callback(error: .NotPoweredOn)
        }
    }

    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        //        log.verbose("")
        guard let callback = self.scanCallback else {
            log.warning("No one handle discover")
            return
        }

        var targetDevice: Device?
        for device in self.discoveredDevices {
            if device.peripheral == peripheral {
                targetDevice = device
                break
            }
        }

        if let device = targetDevice {
            device.advertisementData = advertisementData
            device.RSSI = RSSI
            callback(result: .Success(device))
        } else {
            let device = Device(harald: self, peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI)
            self.discoveredDevices.append(device)
            callback(result: .Success(device))
        }
    }

    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        log.verbose()
        deviceConnecting[peripheral]?.handleConnection(nil)
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        log.warning("error: \(error)")
        if let device = deviceConnecting[peripheral] {
            deviceConnecting.removeValueForKey(peripheral)
            device.handleConnection(.ConnectionFailed)
        } else {
            log.warning("No one to handle failed disconnection")
        }
    }

    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        log.warning("error: \(error)")

        if let device = deviceConnecting[peripheral] {
            deviceConnecting.removeValueForKey(peripheral)
            device.handleDisconnection(error == nil ? nil : .DisconectedUnexpectedly)
        } else {
            log.warning("No one to handle disconection")
        }
    }
}

extension Harald {
    enum Error: Int, NSErrorConvertible {
        case NotPoweredOn
        case IsScanning
        case Timeout

        // MARK: - NSErrorConvertible

        var domain: String {
            return "HaraldErrorDomain"
        }
    }

    func isPoweredOn() -> Bool {
        return central.isPoweredOn()
    }
}

extension CBCentralManager {
    func isPoweredOn() -> Bool {
        return state == .PoweredOn
    }
}

extension CBCentralManagerState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .PoweredOff:
            return "PoweredOff"
        case .PoweredOn:
            return "PoweredOn"
        case .Resetting:
            return "Resetting"
        case .Unauthorized:
            return "Unauthorized"
        case .Unknown:
            return "Unknown"
        case .Unsupported:
            return "Unsupproted"
        }
    }
}
