//
//  WKScriptMessage+Extensions.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-06.
//

import WebKit

extension WKScriptMessage {

    static let decoder = JSONDecoder()

    var stringBody: String? {
        body as? String
    }

    var dataBody: Data? {
        stringBody?.data(using: .utf8)
    }

    func decode<T: Decodable>() throws -> T {
        guard let data = dataBody else {
            throw Errors.cannotDecodeMessage
        }

        return try Self.decoder.decode(T.self, from: data)
    }
}
