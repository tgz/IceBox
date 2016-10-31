//
//  MasterViewController.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit
import CoreBluetooth

struct DeviceWrapper {
    let device: Device
    let updateTime: NSDate

    var connectable: Bool {
        return updateTime.timeIntervalSinceNow > -30
    }
}

let defaults = NSUserDefaults.standardUserDefaults()

class MasterViewController: UITableViewController, UINavigationControllerDelegate {
    var devices = [DeviceWrapper]()
    var discoveredDeviceNames = [String]()
    var filterDeviceNames = Set<String>()

    var alert: UIAlertController?

    var targetDevice: TempBox?

    var isRefreshing: Bool = false
    var scanning = true {
        didSet {
            refreshScanStopButton()
        }
    }

    let deviceController = DeviceController.instance

    @IBOutlet var stopScanButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.contentInset = UIEdgeInsets(top: 64, left: 0, bottom: 0, right: 0)
        self.tableView.registerNib(UINib(nibName: "ScanResultTableViewCell", bundle: nil), forCellReuseIdentifier: "ScanResultCell")
        if let customSubview = NSBundle.mainBundle().loadNibNamed("ScanDeviceRefreshView", owner: self, options: nil).first as? ScanDeviceRefreshView {
            tableView.addPullToRefreshWithAction({
                self.devices.removeAll()
                self.tableView.reloadData()
                self.startScan()
                }, withAnimator: customSubview)
        }
        tableView.alwaysBounceVertical = true
    }


    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if let _ = deviceController.deviceLinker.currentLink {
            self.noticeInfo("正在断开连接...", autoClear: false)
            deviceController.unlink({
                self.clearAllNotice()
                self.noticeTop("连接已断开")
            })
        } else {
            tableView.startPullToRefresh()
        }
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        self.stopScan()
        self.clearAllNotice()
    }

    @IBAction func stopScanButtonPressed(sender: AnyObject) {
        stopScan()
    }

    func refreshScanStopButton() {
        stopScanButton.enabled = scanning
    }

    func startScan() {
        log.info("")
        scanning = true
        refreshControl?.beginRefreshing()
        deviceController.scan(scanned: { (device) in
            guard let name = device.name where name.isEmpty == false else {
//                log.verbose("nil name device filtered")
                return
            }

            guard let UUID = device.advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
                where UUID.first?.UUIDString == TempBox.UUIDConstants().service16Bits.UUIDString
                else {
                    return
            }

            var targetIndex: Int?
            for index in 0..<self.devices.count {
                let wrapper = self.devices[index]
                if wrapper.device.peripheral == device.peripheral {
                    targetIndex = index
                    break
                }
            }

            let wrapper = DeviceWrapper(device: device, updateTime: NSDate())
            if let index = targetIndex {
                self.devices[index] = wrapper
            } else {
                self.devices.append(wrapper)
                if self.discoveredDeviceNames.contains(name) == false {
                    self.discoveredDeviceNames.append(name)
                }
            }

            self.refreshTableView()
        }) { (error) in
            if let err = error {
                self.noticeError(err.reason)
            }
        }
    }

    func stopScan() {
        tableView.stopPullToRefresh()
        deviceController.stopScan()
        scanning = false
    }

    func refreshTableView() {
        if isRefreshing {
            return
        }

        isRefreshing = true
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC) * 0.5)), dispatch_get_main_queue()) { [weak self] () -> Void in
            guard let strongSelf = self else {
                log.error("Nil self.")
                return
            }

            strongSelf.tableView.reloadData()
            strongSelf.isRefreshing = false
        }
    }

    func filterDevices() {
        if filterDeviceNames.isEmpty {
            return
        }
        devices = devices.filter({ (wrapper) -> Bool in
            if let name = wrapper.device.name {
                if self.filterDeviceNames.contains(name) {
                    return true
                }
            }

            return false
        })
        tableView.reloadData()
    }

    // MARK: - Table View

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ScanResultCell", forIndexPath: indexPath) as! ScanResultTableViewCell

        let wrapper = devices[indexPath.row]
        cell.setDevice(wrapper.device)

        cell.nameLabel.textColor = wrapper.connectable ? UIColor.blackColor() : UIColor.lightGrayColor()
        cell.selectionStyle = wrapper.connectable ? UITableViewCellSelectionStyle.Gray : UITableViewCellSelectionStyle.None

        return cell
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        stopScan()
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        let deviceWrapper = devices[indexPath.row]
        if deviceWrapper.connectable == false {
            self.noticeError("30秒内未搜索到此设备，无法连接")
            return
        }

        let device = deviceWrapper.device
        guard let _ = device.MAC, _ = device.name else {
            noticeError("MAC / 名称 为空！", autoClear: true, autoClearTime: 1)
            return
        }

        guard let UUID = device.advertisementData?[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
            where UUID.first?.UUIDString == TempBox.UUIDConstants().service16Bits.UUIDString
            else {
                self.noticeError("设备不受支持", autoClear: true, autoClearTime: 2)
                return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewControllerWithIdentifier("Operation") as! DeviceOpeartionTableViewController
        controller.device = device
        self.navigationController?.pushViewController(controller, animated: true)
    }
}

class RefreshControl: UIRefreshControl {
    override init() {
        super.init()
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    func setup() {
        self.tintColor = UIColor.lightGrayColor()
        self.attributedTitle = NSAttributedString(string: "正在搜索设备")
    }

    override func updateConstraints() {
        super.updateConstraints()

        
    }
}
