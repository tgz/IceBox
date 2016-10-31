//
//  DeviceLinker.swift
//  IceBox
//
//  Created by QSC on 16/7/9.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation
import CoreBluetooth
import Result

final class DeviceLinker {
    let harald = Harald()
    var autoRelink = true

    private(set) var target: LinkTarget?
    private(set) var currentLink: Linkable?

    private var haraldStateNotifier: Disposable?
    private var disconnectNotifier: Disposable?
    private var scanning = false
    private var linking = false

    init() {
        log.debug()
        haraldStateNotifier = harald.subscribeState({ [weak self] (state) in
            log.debug(state)
            self?.haraldStateUpdated(state)
            })
    }

    deinit {
        log.debug()
    }

    // MARK: - Public

    /**
     扫描设备

     - parameter timeout:    超时时长
     - parameter duplicate:  是否允许返回重复的设备。可用于刷新设备的广播包
     - parameter scanned:    扫描回调，每次发现一个设备时立刻返回
     - parameter completion: 扫描完成回调
     */
    func scan(timeout timeout: NSTimeInterval? = nil,
              duplicate: Bool = false,
              scanned: (Device) -> Void,
              completion: ((Error?) -> Void)?) {

        guard scanning == false else {
            completion?(.Busy)
            return
        }
        scanning = true

        harald.scanPeripherals(timeout: timeout, duplicate: duplicate, callback: { (result) in
            switch result {
            case .Success(let device):
                scanned(device)
            case .Failure(let error):
                log.error(error)
                self.scanning = false
                if error == .Timeout {
                    completion?(nil)
                } else {
                    if error == .NotPoweredOn {
                        completion?(.NotPoweredOn)
                    } else {
                        completion?(.ScanFailed)
                    }
                }
            }
        })
    }

    /**
     终止扫描
     */
    func stopScan() {
        harald.stopScan()
        scanning = false
    }

    /**
     连接设备

     - parameter target:     目标设备信息
     - parameter device:     目标设备。用于连接已扫描到的设备
     - parameter autoRelink: 是否开启自动重连。开启后，设备断开连接后会尝试重连
     - parameter completion: 连接完成回调
     */
    func link(target target: LinkTarget, device: Device? = nil, autoRelink: Bool, completion: (Result<Linkable, Error>) -> Void) {
        if let activeLink = currentLink {
            if let activeTarget = self.target where activeTarget == target {
                completion(.Success(activeLink))
                return
            }
            unlink({
                self.link(target: target, device: device, autoRelink: autoRelink, completion: completion)
            })
            return
        }

        guard linking == false else {
            completion(.Failure(.Busy))
            return
        }
        linking = true
        self.target = target
        self.autoRelink = autoRelink

        func handleLinkResult(result: Result<Linkable, Error>) {
            log.info("handle link result:\(result)")
            self.linking = false
            switch result {
            case .Failure(let error):
                completion(.Failure(error))
            case .Success(let linkable):
                self.currentLink = linkable
                self.disconnectNotifier = linkable.target
                    .disconnectionEvent
                    .addHandler({ [weak self] (_) in
                        self?.currentLinkDisconnected()
                        })
                self.postNotification(.Connect, object: nil, userInfo: ["MAC": target.MAC, "name": target.name])
                completion(.Success(linkable))
            }
        }

        if let device = device {
            link(device: device, name: target.name, completion: handleLinkResult)
        } else {

            link(byMAC: target.MAC, name: target.name, completion: handleLinkResult)
        }
    }

    /**
     连接到指定类型的设备

     - parameter target:     目标设备信息
     - parameter type:       设备 wrapper 类型
     - parameter completion: 完成回调
     */
    func link<T: Linkable>(target target: LinkTarget, type: T.Type, completion: (Result<T, Error>) -> Void) {
        link(target: target, autoRelink: true) { (result) in
            if let linkable = result.value {
                if let targetLink = linkable as? T {
                    completion(.Success(targetLink))
                } else {
                    self.unlink({
                        completion(.Failure(.LinkFailed))
                    })
                }
            } else {
                completion(.Failure(.LinkFailed))
            }
        }
    }

    /**
     断开当前持有的连接设备

     - parameter callback: 断开回调
     */
    func unlink(callback: (() -> Void)?) {
        log.debug()
        if let link = currentLink {
            link.unlink({ (_) in
                self.disconnectNotifier = nil
                self.currentLink = nil
                if self.autoRelink == false {
                    self.target = nil
                }
                self.linking = false
                callback?()
            })
        } else {
            linking = false
            callback?()
        }
    }

    /**
     判断是否处于连接状态。连接状态包含设备连接成功，服务、特征值都已发现完毕

     - returns: `true` 为连接状态正常
     */
    func isLinked() -> Bool {
        guard harald.central.state == .PoweredOn else {
            return false
        }
        guard let link = currentLink where link.isLinked else {
            return false
        }
        return true
    }

    // MARK: - Private

    func retrieveConnectedDevices(byDeviceNames names: [String]) -> [Device] {
        var devices = [Device]()
        names.forEach { (name) in
            let UUIDs = [TempBox.UUIDConstants().service128Bits]
            let name = name
            let results = harald.retrieveConnectedDevices(byServiceUUIDs: UUIDs, name: name)
            devices.appendContentsOf(results)
        }
        return devices
    }

    private func link(byMAC MAC: String, name: String, completion: (Result<Linkable, Error>) -> Void) {
        if let device = retrieveConnectedDevices(byDeviceNames: [name]).first {
            link(device: device, name: name, completion: completion)
            return
        }
        scan(timeout: 15, scanned: { (device) in
            guard device.MAC == MAC else {
                return
            }
            self.stopScan()
            self.link(device: device, name: name, completion: completion)
        }) { (error) in
            if let error = error {
                log.error(error)
                completion(.Failure(error))
            }
        }
    }

    private func link(device device: Device, name: String, completion: (Result<Linkable, Error>) -> Void) {
        let linkable: Linkable = TempBox(device: device)

        linkable.link({ (error) in
            if error != nil {
                linkable.unlink({ (_) in
                    completion(.Failure(.LinkFailed))
                })
            } else {
                completion(.Success(linkable))
            }
        })
    }

    // MARK: - State handler

    private func haraldStateUpdated(state: CBCentralManagerState) {
        log.debug(state)
        if state == .PoweredOn {
            postNotification(.PowerOn)
        } else {
            unlink(nil)
            currentLinkDisconnected()
            postNotification(.PowerOff)
        }
    }

    private func currentLinkDisconnected() {
        postNotification(.Disconnect)
        relink()
        disconnectNotifier = nil
    }

    private func relink() {
        log.debug("target: \(target), autoRelink: \(autoRelink)")
        guard let target = target where autoRelink else { return }
        unlink({
            self.link(target: target, autoRelink: true, completion: { (result) in
                if result.isSuccess {
                    return
                }
                Timer.after(0.5, block: { [weak self] in
                    self?.relink()
                    })
            })
        })
    }
}

extension DeviceLinker: Notifier {
    enum Notification: String {
        case Disconnect
        case Connect
        case PowerOff
        case PowerOn
    }
}

extension DeviceLinker {
    enum Error: Int, NSErrorConvertible {
        case NotPoweredOn
        case UnsupportedDevice
        case Timeout
        case Busy
        case ScanFailed
        case LinkFailed
        case NotFound

        var domain: String {
            return "DeviceErrorDomain"
        }
    }

    /**
     扫描选项

     - Include: 扫描包含 bootloader 状态的设备
     - Exclude: 扫描不包含 bootloader 状态的设备
     - Only:    仅扫描 bootloader 状态的设备
     */
    enum ScanBootloaderOption {
        case Include
        case Exclude
        case Only
    }
}

/**
 *  目标连接设备
 */
struct LinkTarget {
    let MAC: String
    let name: String

    init(MAC: String, name: String) {
        self.MAC = MAC
        self.name = name
    }
}

func == (lhs: LinkTarget, rhs: LinkTarget) -> Bool {
    return lhs.MAC == rhs.MAC && lhs.name == rhs.name
}
