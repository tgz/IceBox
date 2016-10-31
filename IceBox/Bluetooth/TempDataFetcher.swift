//
//  TempDataFetcher.swift
//  IceBox
//
//  Created by QSC on 16/7/9.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation
import Result

struct Temperature {
    let date: NSDate
    let temp: Float

    init(date: NSDate, temp: Float) {
        self.date = date
        self.temp = temp
    }

    /**
     日期字符串 + 时间 生成 Temp

     - parameter dateString: 日期格式 `yyyy-MM-dd HH:mm`
     - parameter temp:       温度

     - returns: Temp
     */
    init?(dateString: String, temp: Float) {
        let foramt = NSDateFormatter()
        foramt.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = foramt.dateFromString(dateString) {
            self.date = date
            self.temp = temp
        } else {
            return nil
        }
    }

    func toString() -> String {
        return "\(date.stringwithForamt("yyyy-MM-dd HH:mm")) -> \(temp)"
    }

}

class TempDataFetcher {

    var packageBytes = [UInt8]()
    var totalbytes = 0
    var totalPackages = 0
    var totalReadPackages = 0

    let device: TempBox

    var finishCallback: ((Result<[Temperature], Error>) -> Void)?

    var progressUpdated: ((progress: Float) -> Void)?

    init(device: TempBox) {
        self.device = device
    }

    func fetchData(callback: (Result<[Temperature], Error>) -> Void) {
        self.finishCallback = callback
        device.requestByAPI(.FetchTempData) { [unowned self] (result) in
            switch result {
            case let .Success(data):
                guard let payload = data.first else { self.finish(.Failure(.ParseError)); return }

                let bytes = UnsafePointer<UInt8>(payload.bytes)

                if bytes[0] == 0x55 && bytes[1] == 0x05 {
                    self.totalbytes = Int(bytes[2].toUInt16() << 8 | bytes[3].toUInt16())
                    self.totalPackages =  Int(bytes[4].toUInt16() << 8 | bytes[5].toUInt16())
                    log.warning("total bytes:\(self.totalbytes) total packages:\(self.totalPackages)")
                    if self.totalbytes < 1 && self.totalPackages < 1 {
                        self.finish(.Failure(.EmptyData))
                        return
                    }
                } else {
                    self.finish(.Failure(.ParseError))
                    return
                }
                self.startFetchData()
            case let .Failure(error):
                log.error(error)
                self.finish(.Failure(.ResponseError))
            }

        }
    }

    func startFetchData() {

        let command = BLEAPI.SendACK(type: .FetchTempData, success: true).commandValue()!
        device.fetchDataWithCommand(command) { (result) in
            guard let result = result.value else { self.finish(.Failure(.ParseError)); return }
            self.totalReadPackages += result.count
            result.forEach({ (frame) in
                self.packageBytes += frame.toBytes().suffixFrom(1)
            })
            log.info("totalRead:\(self.totalReadPackages), total:\(self.totalPackages),packageBytes:\(self.packageBytes.count) totalBytes:\(self.totalbytes)")
            self.progressUpdated?(progress: Float(self.packageBytes.count) / Float(self.totalbytes))
            if self.totalReadPackages < self.totalPackages {
                self.startFetchData()
            } else {
                self.parsePackage(self.packageBytes)
            }

        }
    }

    func parsePackage(allBytes: [UInt8]) {
        let spamCount = allBytes.count % 8
        var bytes = allBytes
        if spamCount > 0 {
            log.warning("data not neat, remove last \(spamCount) bytes")
            log.verbose(allBytes)
            var temp = [UInt8]()
            for index in 0 ..< bytes.count - spamCount {
                temp.append(bytes[index])
            }
            bytes = temp
        }

        func parse(frame: ArraySlice<UInt8>) -> Temperature? {
            let offset = frame.startIndex
            let year = (frame[offset + 1].toUInt16() << 8) | (frame[offset].toUInt16())
            let month = frame[offset + 2]
            let day = frame[offset + 3]
            let hour = frame[offset + 4]
            let minute = frame[offset + 5]
            let temp = Float((frame[offset + 7].toUInt16() << 8) | (frame[offset + 6].toUInt16())) / 10
            log.verbose("time:\(year)-\(month)-\(day) \(hour):\(minute) -> \(temp)")
            return Temperature(dateString: "\(year)-\(month)-\(day) \(hour):\(minute)", temp: temp)
        }

        var temps = [Temperature]()

        for index in 0.stride(to: bytes.count, by: 8) {
            let frame = bytes[index ..< index + 8]
            if let result = parse(frame) {
                temps.append(result)
            }
        }
        finishCallback?(.Success(temps))

        self.packageBytes = [UInt8]()
        self.totalbytes = 0
        self.totalPackages = 0
        self.totalReadPackages = 0

    }

    func finish(result: Result<[Temperature], Error>) {
        device.device.updateCallback = nil
        finishCallback?(result)
    }
}

extension TempDataFetcher {
    enum Error: ErrorType {
        case ResponseError
        case ParseError
        case EmptyData
    }
}
