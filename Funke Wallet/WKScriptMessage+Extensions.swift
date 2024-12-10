//
//  WKScriptMessage+Extensions.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-12-06.
//

import WebKit

extension WKScriptMessage {
    
    func parseJSON<T : Decodable>() -> T? {
//        guard let jsonString = self.body as? String else { return nil }
//        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
//        do {
//            let result = try JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments])
//            print(result)
//        } catch {
//            print(error)
//        }
        
        
        
        
        guard let jsonString = self.body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? T else {
            return nil
        }
        return result
    }
    
    
    
    func jsonDictionary() -> [String: Any]? {
        guard let jsonString = self.body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let jsonDictionary = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            return nil
        }
        return jsonDictionary
    }
    
    func jsonString() -> String? {
        guard let jsonString = self.body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let jsonString = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? String else {
            return nil
        }
        return jsonString
    }
}
