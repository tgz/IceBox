//
//  ScanDeviceRefreshView.swift
//  IceBox
//
//  Created by QSC on 16/7/30.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit

class ScanDeviceRefreshView: UIView, PullToRefreshViewDelegate {

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var titleLabel: UILabel!

    func pullToRefreshAnimationDidStart(view: PullToRefreshView) {
        activityIndicator.startAnimating()
        titleLabel.text = "正在刷新设备"
    }

    func pullToRefreshAnimationDidEnd(view: PullToRefreshView) {
        activityIndicator.stopAnimating()
        titleLabel.text = ""
    }

    func pullToRefresh(view: PullToRefreshView, progressDidChange progress: CGFloat) {
        
    }

    func pullToRefresh(view: PullToRefreshView, stateDidChange state: PullToRefreshViewState) {

        switch state {
        case .Loading:
            titleLabel.text = "正在刷新设备"
        case .PullToRefresh:
            titleLabel.text = "下拉刷新设备"
        case .ReleaseToRefresh:
            titleLabel.text = "释放以刷新"
        }
    }
}
