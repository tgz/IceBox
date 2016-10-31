//
//  DeviceOpeartionTableViewController.swift
//  IceBox
//
//  Created by QSC on 16/7/15.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit

class DeviceOpeartionTableViewController: UITableViewController {

    var tempBox: TempBox?
    let deviceController = DeviceController.instance
    var device: Device?

    var fetcher: TempDataFetcher?

    var name: String = "name"
    var mac: String = "MAC"

    var nameTextField: UITextField?
    var intervalTextField: UITextField?
    var lastReadTimeLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerNib(UINib(nibName: "DeviceInfoTableViewCell", bundle: nil), forCellReuseIdentifier: "Info")

        tableView.registerNib(UINib(nibName: "InputAndConfirmTableViewCell", bundle: nil), forCellReuseIdentifier: "InputAndConfirm")


    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        guard let name = device?.name, mac = device?.MAC else {
            self.navigationController?.popViewControllerAnimated(true)
            return
        }
        self.noticeInfo("连接中...")
        deviceController.link(target: LinkTarget(MAC: mac, name: name), device: device) { [weak self] (result) in
            guard let `self` = self else { return }
            log.info("link finished")
            log.info(result)
            dispatch_async(dispatch_get_main_queue(), {
                if let linkedTempBox = result.value as? TempBox {
                    self.clearAllNotice()
                    self.noticeTop("连接成功", autoClear: true, autoClearTime: 2)
                    self.tempBox = linkedTempBox
                    self.name = name
                    self.mac = mac
                    self.saveDeviceInfo(name, mac: mac)
                    self.queryLastRecordData(mac, callback: { (time) in
                        self.lastReadTimeLabel?.text = time
                    })
                    self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: .Automatic)

                } else {
                    self.clearAllNotice()
                    self.noticeError("连接失败!\n\(result.error)", autoClear: true, autoClearTime: 2)
                    self.navigationController?.popViewControllerAnimated(true)
                }
            })
        }
    }

    func goToHistory() {
        guard let mac = device?.MAC else {
            clearAllNotice()
            noticeError("设备 MAC 地址未知！")
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("RecordHistory") as! DeviceHistoryTableViewController
        controller.MAC = mac
        controller.title = name
        self.navigationController?.pushViewController(controller, animated: true)
    }

    func updateTime() {
        let date = NSDate()
        self.noticeInfo("请稍后……")
        tempBox?.requestByAPI(.SetTime(date: date), callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
                if let response = result.value?.first?.toBytes() {
                    if response[2] == 1 {
                        self.noticeSuccess("保存成功")
                        return
                    }
                }
                self.noticeError("保存失败：\n \(result.error?.reason ?? "")")
            })
//            self.setResult("\(result)")
        })
    }

    func reboot() {
        self.noticeInfo("请稍后……")
        tempBox?.requestByAPI(.Reset, callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
                if result.isSuccess {
                    self.noticeSuccess("命令发送成功")
                } else {
                    self.noticeError("保存失败：\n \(result.error?.reason ?? "")")
                }
            })

        })
    }

    func didPressRenameButton() {
        view.endEditing(true)
        self.noticeInfo("请稍后……")
        guard let name = nameTextField?.text where name.characters.count > 0 else {
            self.clearAllNotice()
            self.noticeError("请输入需要设置的名称！")
            return
        }
        tempBox?.requestByAPI(.Rename(name: name), callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
                if let response = result.value?.first?.toBytes() {
                    if response[2] == 1 {
                        self.noticeSuccess("保存成功")
                        return
                    }
                }
                self.noticeError("保存失败：\n \(result.error?.reason ?? "")")
            })
        })
    }

    func didPressSetIntervalButton() {
        view.endEditing(true)
        self.noticeInfo("请稍后……")
        guard let text = intervalTextField?.text, interval = Int(text) else {
            self.clearAllNotice()
            self.noticeError("请输入需要设置的时间！(分钟)")
            return
        }
        tempBox?.requestByAPI(BLEAPI.SetSamplingInterval(interval: interval), callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
                if let response = result.value?.first?.toBytes() {
                    if response[2] == 1 {
                        self.noticeSuccess("保存成功")
                        return
                    }
                }
                self.noticeError("保存失败：\n \(result.error?.reason ?? "")")
            })
        })
    }

    func fetchData() {
        self.noticeInfo("请稍后……")

        guard let device = tempBox, mac = device.device.MAC else {
            self.clearAllNotice()
            self.noticeError("设备信息丢失，请退出重新连接")
            return
        }
        if fetcher == nil {
            fetcher = TempDataFetcher(device: device)
//            fetcher?.progressUpdated = showProgress
        }
        fetcher?.fetchData { [unowned self] (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
            })
            switch result {
            case let .Success(temps):
                self.saveTempInfo(temps, mac: mac)
                dispatch_async(dispatch_get_main_queue(), {
                    self.clearAllNotice()
                    self.noticeSuccess("读取成功！\n读取到 \(temps.count) 条数据")
                    self.lastReadTimeLabel?.text = NSDate().stringwithForamt("yyyy-MM-dd HH:mm")
                })
            case let .Failure(error) :
                dispatch_async(dispatch_get_main_queue(), {
                    self.clearAllNotice()
                    self.noticeError("读取数据出错 \n \(error)")
                })
            }
        }
    }
    /*
     func showProgress(progress: Float) {
     dispatch_async(dispatch_get_main_queue()) {
     //            self.textView.text = String(format: "当前进度：%0.2f %%", progress * 100)
     }
     }

    @IBAction func fetchSamplingInterval(sender: AnyObject) {
        self.noticeInfo("请稍后……")
        tempBox?.requestByAPI(BLEAPI.FetchSamplingInterval, callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
            })
            if result.isSuccess {
                if let bytes = result.value?.first?.toBytes() {
                    self.setResult("response: \(result)  \n --> 采样间隔为 " + String(format: "%d 分钟",  bytes[2]))
                } else {
                    self.setResult("\(result)")
                }
            } else {
                self.setResult("\(result)")
            }
        })
    }
*/
    func wipeData() {
        self.noticeInfo("请稍后……")
        tempBox?.requestByAPI(BLEAPI.WipeData, callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
                if let response = result.value?.first?.toBytes() {
                    if response[2] == 1 {
                        self.noticeSuccess("数据擦除成功")
                        return
                    }
                }
                self.noticeError("擦除失败：\n \(result.error?.reason ?? "")")
            })

        })
    }

    func saveTempInfo(temp: [Temperature], mac: String) {
        deviceController.writeInRealm({ (realm) in
            let record = temp.map({ RMTempRecord(mac: mac, temp: $0) })
            realm.add(record)
        }) { (error) in
            log.info("write in realm finished")
            if let err = error {
                log.error(err)
            }
        }
    }

    func saveDeviceInfo(name: String, mac: String) {
        deviceController.writeInRealm({ (realm) in
            let box = RMTempBox()
            box.name = String(name)
            box.MAC = String(mac)
            box.lastLinkDate = NSDate()
            realm.add(box, update: true)
        }) { (error) in
            log.info("write device finished")
            if let err = error {
                log.error(err)
            }
        }
    }

    func queryLastRecordData(mac: String, callback: (String) -> Void) {
        var time = "--"
        deviceController.readInRealm({ (realm) in

            let predicate = NSPredicate(format: "MAC = %@", mac)

            if let record = realm.objects(RMTempRecord).filter(predicate).sorted("date", ascending: false).first {
                time = record.date.stringwithForamt("yyyy-MM-dd HH:mm")
            }
        }) { [weak self] (error) in
            guard let `self` = self else { return }
            if let err = error {
                log.error(err)
            }
            callback(time)
            self.lastReadTimeLabel?.text = time
        }
    }

    // MARK: - Mock data
//
//    override func canBecomeFirstResponder() -> Bool {
//        return true
//    }
//
//    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
//        mockData()
//    }

    func mockData() {
        var temps = [Temperature]()
        for _ in 0...30 {
            let randomDate = NSDate().dateByAddingTimeInterval(NSTimeInterval(60 * (Int(arc4random()) % 1000)))
            let temp = Temperature(date: randomDate, temp: Float(arc4random() % 90) / 3.0)
            temps.append(temp)
        }
        log.info("mock:\(temps.count), \(device!.MAC!)")

        saveTempInfo(temps, mac: device!.MAC!)
        self.lastReadTimeLabel?.text = NSDate().stringwithForamt("yyyy-MM-dd HH:mm")
    }
}

extension DeviceOpeartionTableViewController {

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return 4
        } else {
            return 2
        }
    }

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }

    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 12
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("Info", forIndexPath: indexPath) as! DeviceInfoTableViewCell
                cell.nameLabel.text = self.name
                cell.macLabel.text = self.mac
                return cell
            } else {
                let cell = tableView.dequeueReusableCellWithIdentifier("SingleTitle", forIndexPath: indexPath)
                cell.textLabel?.text = "查看历史数据"
                cell.imageView?.image = UIImage(named: "setting_setting")
                return cell
            }
        } else if indexPath.section == 1 {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("TitleWithDetail", forIndexPath: indexPath)
                cell.textLabel?.text = "读取温度数据"
                cell.detailTextLabel?.text = "上次读取时间："
                lastReadTimeLabel = cell.detailTextLabel
                cell.imageView?.image = UIImage(named: "setting_setting")
                return cell
            } else if indexPath.row == 1 {
                let cell = tableView.dequeueReusableCellWithIdentifier("SingleTitle", forIndexPath: indexPath)
                cell.imageView?.image = UIImage(named: "setting_setting")
                cell.textLabel?.text = "修改箱子时间"
                return cell
            }  else if indexPath.row == 2 {
                let cell = tableView.dequeueReusableCellWithIdentifier("InputAndConfirm", forIndexPath: indexPath) as! InputAndConfirmTableViewCell
                cell.imageView?.image = UIImage(named: "setting_setting")
                cell.titleLabel?.text = "修改箱子名称"
                cell.input.delegate = self
                self.nameTextField = cell.input
                cell.button.addTarget(self, action: #selector(didPressRenameButton), forControlEvents: .TouchUpInside)
                return cell

            }  else if indexPath.row == 3 {
                let cell = tableView.dequeueReusableCellWithIdentifier("InputAndConfirm", forIndexPath: indexPath) as! InputAndConfirmTableViewCell
                cell.imageView?.image = UIImage(named: "setting_setting")
                cell.titleLabel?.text = "修改采样间隔"
                cell.input.delegate = self
                self.intervalTextField = cell.input
                cell.button.addTarget(self, action: #selector(didPressSetIntervalButton), forControlEvents: .TouchUpInside)
                return cell
            }
        } else {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("SingleTitle", forIndexPath: indexPath)
                cell.textLabel?.text = "清空设备数据"
                cell.imageView?.image = UIImage(named: "setting_setting")
                return cell
            } else {
                let cell = tableView.dequeueReusableCellWithIdentifier("SingleTitle", forIndexPath: indexPath)
                cell.textLabel?.text = "箱子系统重启"
                cell.imageView?.image = UIImage(named: "setting_setting")
                return cell
            }
        }
        return UITableViewCell()
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "设备信息"
        } else if section == 1 {
            return "操作"
        } else if section == 2 {
            return "系统"
        }
        return nil
    }

    override func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let section = indexPath.section
        let row = indexPath.row
        if section == 0 && row == 0 {
            return false
        }

        if section == 1 && (row == 2 || row == 3) {
            return false
        }

        return true
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        view.endEditing(true)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        let section = indexPath.section
        let row = indexPath.row

        if section == 0 && row == 1 {
            log.verbose("get history")
            goToHistory()
        }

        if section == 1 && row == 0 {
            log.verbose("fetch data")
            fetchData()
        }

        if section == 1 && row == 1 {
            log.verbose("update time")
            updateTime()
        }

        if section == 2 && row == 0 {
            log.verbose("wipe data")
            wipeData()
        }

        if section == 2 && row == 1 {
            log.verbose("reboot")
            reboot()
        }
    }
 }

extension DeviceOpeartionTableViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }
}
