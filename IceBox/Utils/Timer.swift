//
//  Timer.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//

import Foundation

class Timer {

    private var timerSource: dispatch_source_t

    required init(interval: NSTimeInterval, repeats: Bool = false, queue: dispatch_queue_t = dispatch_get_main_queue(), block: dispatch_block_t) {
        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        let intervalUInt64 = UInt64(max(0, interval) * 1000_000_000)
        dispatch_source_set_timer(timerSource, dispatch_time(DISPATCH_TIME_NOW, Int64(intervalUInt64)), repeats ? intervalUInt64 : DISPATCH_TIME_FOREVER, 0)
        dispatch_source_set_event_handler(timerSource) { () -> Void in
            block()
            if repeats == false {
                self.cancel()
            }
        }
        dispatch_resume(timerSource)
    }

    func cancel() {
        dispatch_source_cancel(timerSource)
    }
}

extension Timer {

    class func after(interval: NSTimeInterval, queue: dispatch_queue_t = dispatch_get_main_queue(), block: dispatch_block_t) -> Timer {
        return self.init(interval: interval, queue: queue, block: block)
    }

    class func every(interval: NSTimeInterval, queue: dispatch_queue_t = dispatch_get_main_queue(), block: dispatch_block_t) -> Timer {
        return self.init(interval: interval, repeats: true, queue: queue, block: block)
    }

}
