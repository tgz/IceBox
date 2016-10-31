//
//  RMTempRecord.swift
//  IceBox
//
//  Created by QSC on 16/7/11.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation
import RealmSwift

class RMTempRecord: Object {
    dynamic var MAC = ""
    dynamic var temperature: Float = 0.0
    dynamic var date = NSDate()

    convenience init(mac: String, temp: Temperature) {
        self.init() //Please note this says 'self' and not 'super'
        self.MAC = mac
        self.temperature = temp.temp
        self.date = temp.date
    }

    func toTemperature() -> Temperature {
        return Temperature(date: date, temp: temperature)
    }
}
