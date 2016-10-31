//
//  SettingTableViewController.swift
//  IceBox
//
//  Created by QSC on 16/7/15.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit

class SettingTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if indexPath.row == 0 {
            clearRealm()
        }

        if indexPath.row == 1 {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let controller = storyboard.instantiateViewControllerWithIdentifier("TutorialViewController")
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }

    func clearRealm() {
        DeviceController.instance.writeInRealm({ (realm) in
            realm.deleteAll()
            }) { (error) in
                if let err = error {
                    self.noticeError("清空数据出错，请重试 \n\(err.localizedDescription)")
                } else {
                    self.noticeSuccess("数据清空完成！")
                }
        }
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
