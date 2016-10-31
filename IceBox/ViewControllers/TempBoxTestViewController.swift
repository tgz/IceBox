//
//  TempBoxTestViewController.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit
import RealmSwift

class TempBoxTestViewController: UIViewController {
    var tempBox: TempBox?
    let deviceController = DeviceController.instance
    var device: Device?

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var macLabel: UILabel!
    @IBOutlet var dataTextField: UITextField!

    @IBOutlet var textView: UITextView!

    var fetcher: TempDataFetcher?
    var tempDataResult: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var description: String {
        return "\(device?.name) - \(device?.MAC)"
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
                    self.nameLabel.text = name
                    self.macLabel.text = mac
                    self.saveDeviceInfo(name, mac: mac)
                } else {
                    self.clearAllNotice()
                    self.noticeError("连接失败!\n\(result.error)", autoClear: true, autoClearTime: 2)
                    self.navigationController?.popViewControllerAnimated(true)
                }
            })
        }
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesBegan(touches, withEvent: event)
        view.endEditing(true)
    }

    @IBAction func setTime(sender: AnyObject) {
        let date = NSDate()
        self.noticeInfo("请稍后……")
        tempBox?.requestByAPI(.SetTime(date: date), callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
            })
            self.setResult("\(result)")
        })
    }

    @IBAction func reset(sender: AnyObject) {
        self.noticeInfo("请稍后……")
        tempBox?.requestByAPI(.Reset, callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
            })
            self.setResult("\(result)")
        })
    }
    @IBAction func rename(sender: AnyObject) {
        self.noticeInfo("请稍后……")
        guard let name = dataTextField.text where name.characters.count > 0 else {
            self.clearAllNotice()
            self.noticeError("请输入需要设置的名称！")
            return
        }
        tempBox?.requestByAPI(.Rename(name: name), callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
            })
            self.setResult("\(result)")
        })
    }
    @IBAction func setSamplingInterval(sender: AnyObject) {
        self.noticeInfo("请稍后……")
        guard let text = dataTextField.text, interval = Int(text) else {
            self.clearAllNotice()
            self.noticeError("请输入需要设置的时间！(分钟)")
            return
        }
        tempBox?.requestByAPI(BLEAPI.SetSamplingInterval(interval: interval), callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
            })
            self.setResult("\(result)")
        })
    }

    func showProgress(progress: Float) {
        dispatch_async(dispatch_get_main_queue()) {
            self.textView.text = String(format: "当前进度：%0.2f %%", progress * 100)
        }
    }

    @IBAction func fetchData(sender: AnyObject) {
        self.noticeInfo("请稍后……")
        tempDataResult = ""
        guard let device = tempBox, mac = device.device.MAC else {
            self.clearAllNotice()
            self.noticeError("设备信息丢失，请退出重新连接")
            return
        }
        if fetcher == nil {
            fetcher = TempDataFetcher(device: device)
            fetcher?.progressUpdated = showProgress
        }
        fetcher?.fetchData { [unowned self] (result) in
            dispatch_async(dispatch_get_main_queue(), { 
                self.clearAllNotice()
            })
            switch result {
            case let .Success(temps):
                self.saveTempInfo(temps, mac: mac)
//                self.wipeData("")
                temps.forEach({ (temp) in
                    self.tempDataResult = temp.toString() + "\n" + self.tempDataResult
                })
                dispatch_async(dispatch_get_main_queue(), {
                    self.textView.text = self.tempDataResult
                })
            case let .Failure(error) :
                dispatch_async(dispatch_get_main_queue(), {
                    self.textView.text = "error:\(error)"
                })
            }
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

    @IBAction func wipeData(sender: AnyObject) {
        self.noticeInfo("请稍后……")
        tempBox?.requestByAPI(BLEAPI.WipeData, callback: { (result) in
            dispatch_async(dispatch_get_main_queue(), {
                self.clearAllNotice()
            })
            self.setResult("\(result)")
        })
    }

    func setResult(result: String) {
        dispatch_async(dispatch_get_main_queue()) { 
            self.textView.text = result
        }
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

    func mockData() {
        var temps = [Temperature]()
        for index in 0...30 {
            let randomDate = NSDate().dateByAddingTimeInterval(NSTimeInterval(60 * index * random() % 1000))
            let temp = Temperature(date: randomDate, temp: Float(random() % 90) / 3.0)
            temps.append(temp)
        }
        log.info("mock:\(temps.count), \(device!.MAC!)")

        saveTempInfo(temps, mac: device!.MAC!)
    }
}
