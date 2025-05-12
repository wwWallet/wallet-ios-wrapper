//
//  MessageHandler.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 21.04.25.
//

import WebKit

class MessageHandler: NSObject, WKScriptMessageHandlerWithReply {

    typealias ReplyHandler = @MainActor @Sendable (WKScriptMessage) async throws -> Any?


    private let handler: ReplyHandler


    init(handler: @escaping ReplyHandler)
    {
        self.handler = handler
    }


    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        do {
            return (try await handler(message), nil)
        }
        catch {
            return (nil, error.localizedDescription)
        }
    }
}
