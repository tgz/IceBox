//
//  Event.swift
//  BLE
//
//  Created by QSC on 16/7/8.
//  Copyright © 2016年 qsc. All rights reserved.
//


protocol Disposable {
    func dispose()
}

class Event<T> {
    typealias Handler = (data: T) -> Void
    private var handlers = [HandlerWrapper<T>]()


    func addHandler(handler: Handler) -> Disposable {
        let handlerWrapper = HandlerWrapper(event: self, handler: handler)
        handlers.append(handlerWrapper)
        return handlerWrapper
    }

    func raise(data: T) {
        for handler in handlers {
            handler.invoke(data)
        }
    }
}

private class HandlerWrapper<T> : Disposable {
    typealias Handler = (data: T) -> Void

    unowned let event: Event<T>
    let handler: Handler


    init(event: Event<T>, handler: Handler) {
        self.event = event
        self.handler = handler
    }

    func invoke(data: T) {
        handler(data: data)
    }

    func dispose() {
        event.handlers = event.handlers.filter({ (wrapper) -> Bool in
            return wrapper !== self
        })
    }
}
