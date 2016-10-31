//
//  DeviceController.swift
//  IceBox
//
//  Created by QSC on 16/7/9.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation
import Result
import RealmSwift

private let realmBackgroundQueue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)

class DeviceController {
    static let instance = DeviceController()
    let deviceLinker = DeviceLinker()

    var targetDevice: LinkTarget? // backup
    deinit {
        log.error("")
    }

    func scan(timeout timeout: NSTimeInterval? = nil,
                      scanned: (Device) -> Void,
                      completion: ((DeviceLinker.Error?) -> Void)?) {
        deviceLinker.scan(timeout: timeout, duplicate: true, scanned: scanned, completion: completion)
    }

    func stopScan() {
        deviceLinker.stopScan()
    }

    func link(target target: LinkTarget, device: Device? = nil, completion: (Result<Linkable, DeviceLinker.Error>) -> Void) {
        deviceLinker.link(target: target, device: device, autoRelink: false, completion: completion)
    }

    func unlink(callback: (() -> Void)? = nil) {
        deviceLinker.unlink { 
            callback?()
        }
    }


    func realm() -> Result<Realm, NSError> {
        do {
            let realm = try Realm()
            return .Success(realm)
        } catch let error as NSError {
            return .Failure(error)
        }
    }

    typealias RealmBlock = (realm: Realm) -> Void

    func writeInRealm(writeBLock: RealmBlock,
                      completionQueue queue: dispatch_queue_t = dispatch_get_main_queue(),
                                      completion: ((error: NSError?) -> Void)) {
        operateInRealm(write: writeBLock, completionQueue: queue, completion: completion)
    }

    func readInRealm(readBlock: RealmBlock,
                     completionQueue queue: dispatch_queue_t = dispatch_get_main_queue(),
                                     completion: ((error: NSError?) -> Void)) {
        operateInRealm(read: readBlock, completionQueue: queue, completion: completion)
    }

    private func operateInRealm(read readBlock: RealmBlock? = nil,
                                     write writeBlock: RealmBlock? = nil,
                                           completionQueue: dispatch_queue_t = dispatch_get_main_queue(),
                                           completion: ((error: NSError?) -> Void)) {
        assert((readBlock == nil && writeBlock == nil) == false, "read and write cannot be both nil")
        dispatch_async(realmBackgroundQueue, { () -> Void in
            let result = self.realm()
            if result.isFailure {
                dispatch_async(completionQueue, { () -> Void in
                    completion(error: result.error!)
                })
                return
            }
            let realm = result.value!
            readBlock?(realm: realm)
            guard let write = writeBlock else {
                dispatch_async(completionQueue, { () -> Void in
                    completion(error: nil)
                })
                return
            }
            do {
                realm.beginWrite()
                write(realm: realm)
                try realm.commitWrite()
                dispatch_async(completionQueue, { () -> Void in
                    completion(error: nil)
                })
            } catch {
                log.error("\(error)")
                dispatch_async(completionQueue, { () -> Void in
                    completion(error: nil)
                })
            }
        })
    }
}
