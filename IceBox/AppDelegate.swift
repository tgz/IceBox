//
//  AppDelegate.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit
import SwiftyBeaver

let log = SwiftyBeaver.self


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let console = ConsoleDestination()
        console.colorOption = .Message
        //        console.minLevel = .Debug

        console.levelString.Verbose = "[V]"
        console.levelString.Debug = "[D]"
        console.levelString.Info = "[I]"
        console.levelString.Warning = "[W]"
        console.levelString.Error = "[E]"

        console.blue = "fg143,161,179;"
        console.green = "fg147,178,121;"
        console.yellow = "fg229,192,121;"
        console.red = "fg175,75,87;"
        console.silver = "fg160,160,160;"

        log.addDestination(console)

        return true
    }
}

