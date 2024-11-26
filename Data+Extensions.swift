//
//  Data+Extensinos.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-25.
//

import Foundation

extension String {
    
    func webSafeBase64DecodedData() -> Data? {
        let base64EncodedString = self.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding: String
        if base64EncodedString.count % 4 != 0 {
            padding = String(repeating: "=", count: 4 - (base64EncodedString.count % 4))
        } else {
            padding = ""
        }
        return Data(base64Encoded: base64EncodedString.appending(padding))
    }
}

extension Data {
    
    func webSafeBase64EncodedString() -> String {
        let base64EncodedString = self.base64EncodedString()
        return base64EncodedString.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    
}
