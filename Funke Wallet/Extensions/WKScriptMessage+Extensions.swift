//
//  WKScriptMessage+Extensions.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-12-06.
//

import WebKit

extension WKScriptMessage {

    func parseJSON<T : Decodable>() -> T? {
        if let jsonString = self.body as? String,
           let jsonData = jsonString.data(using: .utf8),
           let result = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? T
        {
            return result
        }

        return nil
    }

    func jsonDictionary() -> [String: Any]? {
        if let jsonString = self.body as? String,
           let jsonData = jsonString.data(using: .utf8),
           let jsonDictionary = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
        {
            return jsonDictionary
        }

        return nil
    }

    func jsonString() -> String? {
        if let jsonString = self.body as? String,
           let jsonData = jsonString.data(using: .utf8),
           let jsonString = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? String
        {
            return jsonString
        }

        return nil
    }
}
