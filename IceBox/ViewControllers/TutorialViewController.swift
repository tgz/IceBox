//
//  TutorialViewController.swift
//  IceBox
//
//  Created by QSC on 16/7/31.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit
import Cartography

class TutorialViewController: UIViewController {
    @IBOutlet var webView: UIWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let baseURL = NSBundle.mainBundle().bundleURL
        let htmlURL = NSBundle.mainBundle().URLForResource("help.html", withExtension: nil)!
        let htmlContent = try! String(contentsOfURL: htmlURL, encoding: NSUTF8StringEncoding)
        webView.loadHTMLString(htmlContent, baseURL: baseURL)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }
}

extension TutorialViewController: UIWebViewDelegate {

}
