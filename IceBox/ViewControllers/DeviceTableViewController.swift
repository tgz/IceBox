//
//  DeviceTableViewController.swift
//  IceBox
//
//  Created by QSC on 16/7/12.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit
import RealmSwift

class DeviceTableViewController: UITableViewController {

    lazy var history = [DeviceHistory]()

    override func viewDidLoad() {
        super.viewDidLoad()
         self.clearsSelectionOnViewWillAppear = true
        tableView.registerNib(UINib(nibName: "DeviceRecordTableViewCell", bundle: nil), forCellReuseIdentifier: "DeviceCell")

    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        loadDevicesFromRealm() { history in
            self.history = history
            self.tableView.reloadData()
            if history.count == 0 {
                self.noticeInfo("没有数据", autoClearTime: 1)
            }
        }
    }

    // MARK: - Table view data source

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("DeviceCell", forIndexPath: indexPath) as! DeviceRecordTableViewCell
        cell.setHistory(history[indexPath.row])
        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("RecordHistory") as! DeviceHistoryTableViewController
        controller.MAC = history[indexPath.row].MAC
        controller.title = history[indexPath.row].name
        self.navigationController?.pushViewController(controller, animated: true)
    }


    func loadDevicesFromRealm(callback: ([DeviceHistory]) -> Void) {
        log.verbose("")
        var history = [DeviceHistory]()
        DeviceController.instance.readInRealm({ (realm) in
            let results = realm.objects(RMTempBox.self)
              history = results.map({ DeviceHistory(name: $0.name, MAC: $0.MAC, date: $0.lastLinkDate) })
            }) { (error) in
                log.info("load device finished")
                if let err = error {
                    log.error(err)
                }
                callback(history)
        }
    }
}

struct DeviceHistory {
    let name: String
    let MAC: String
    let date: NSDate
}
