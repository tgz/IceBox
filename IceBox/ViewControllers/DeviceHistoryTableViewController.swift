//
//  DeviceHistoryTableViewController.swift
//  IceBox
//
//  Created by QSC on 16/7/12.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit
import RealmSwift

class DeviceHistoryTableViewController: UITableViewController {

    @IBOutlet var minTempLabel: UILabel!
    @IBOutlet var averageTempLabel: UILabel!
    @IBOutlet var maxTempLabel: UILabel!
    var MAC: String?

    lazy var groupedRecord = [[Temperature]]()

    override func viewDidLoad() {
        super.viewDidLoad()

        if MAC == nil {
            self.noticeError("MAC is nil!", autoClear: true)
        }

        tableView.registerNib(UINib(nibName: "TempRecordTableViewCell", bundle: nil), forCellReuseIdentifier: "RecordCell")
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        loadDeviceRecordFromRealm() { records in
            self.groupedRecord = records
            self.tableView.reloadData()

            if records.count == 0 {
                self.noticeInfo("没有数据", autoClearTime: 1)
            }
        }
    }

    func loadDeviceRecordFromRealm(callback: ([[Temperature]]) -> Void) {
        var records = [Temperature]()
        var groupedRecord = [[Temperature]]()
        guard let mac = MAC else {
            log.error("mac is nil!")
            callback(groupedRecord)
            return
        }

        DeviceController.instance.readInRealm({ (realm) in
            let predicate = NSPredicate(format: "MAC = %@", mac)

            let result = realm.objects(RMTempRecord.self).filter(predicate).sorted("date", ascending: false)

            records = result.map({ $0.toTemperature() })

            records.forEach({ (record) in
                let currentGroupCount = groupedRecord.count
                if currentGroupCount == 0 {
                    groupedRecord.append([record])
                    return
                }

                let currentGroupIndex = currentGroupCount - 1
                if let lastDate = groupedRecord[currentGroupIndex].last?.date {
                    if lastDate.ignoreMinute() == record.date.ignoreMinute() {
                        groupedRecord[currentGroupIndex].append(record)
                    } else {
                        groupedRecord.append([record])
                    }
                } else {
                    groupedRecord.append([record])
                }
            })

            dispatch_async(dispatch_get_main_queue(), {
                if let min = records.first?.temp {
                    self.minTempLabel.text = String(format: "%.1f", min)
                } else {
                    self.minTempLabel.text = "--"
                }

                if let max = records.last?.temp {
                    self.maxTempLabel.text = String(format: "%.1f", max)
                } else {
                    self.maxTempLabel.text = "--"
                }

                let all = records.reduce(Float(0), combine: { $0 + $1.temp})
                if records.count > 0 {
                    let avg = all / Float(records.count)
                    self.averageTempLabel.text = String(format: "%.2f", avg)
                } else {
                    self.averageTempLabel.text = "--"
                }
            })

            }) { (error) in
                log.info("load record finished")
                if let err = error {
                    log.error(err)
                }

                callback(groupedRecord)
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return groupedRecord.count
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return groupedRecord[section].count
    }

    override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("RecordCell", forIndexPath: indexPath) as! TempRecordTableViewCell
        cell.setTemperaure(groupedRecord[indexPath.section][indexPath.row])
        return cell
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let records = groupedRecord[section]
        guard records.count > 0 else { return nil }
        var title = records[0].date.stringwithForamt("yyyy-MM-dd HH时 ")
        let all = records.reduce(Float(0), combine: { $0 + $1.temp})

        let avg = all / Float(records.count)
        title += String(format: "  平均温度 %.1f", avg)

        return title
    }

    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 12
    }

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 28
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension NSDate {
    func ignoreTime() -> NSDate {
        let cal = NSCalendar.currentCalendar()
        let components = cal.components([.Year, .Month, .Day], fromDate: self)
        return cal.dateFromComponents(components)!
    }

    func ignoreMinute() -> NSDate {
        let cal = NSCalendar.currentCalendar()
        let components = cal.components([.Year, .Month, .Day, .Hour], fromDate: self)
        return cal.dateFromComponents(components)!
    }
}
