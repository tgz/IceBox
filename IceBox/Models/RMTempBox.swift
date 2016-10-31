//
//  RMTempBox.swift
//  IceBox
//
//  Created by QSC on 16/7/11.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation
import RealmSwift

class RMTempBox: Object {
    dynamic var name = ""
    dynamic var MAC = ""
    dynamic var lastLinkDate = NSDate()

    override static func primaryKey() -> String? {
        return "MAC"
    }

    convenience init(mac: String, name: String, date: NSDate) {
        self.init() //Please note this says 'self' and not 'super'
        self.MAC = mac
        self.name = name
        self.lastLinkDate = date
    }
}
