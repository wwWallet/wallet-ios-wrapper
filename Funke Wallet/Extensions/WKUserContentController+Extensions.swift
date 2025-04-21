//
//  WKUserContentController+Extensions.swift
//  Funke Wallet
//
//  Created by Benjamin Erhart on 21.04.25.
//

import WebKit

extension WKUserContentController {

    func addPageHandler(named name: String, handler: @escaping MessageHandler.ReplyHandler) {
        addScriptMessageHandler(MessageHandler(handler: handler), contentWorld: .page, name: name)
    }
}
