//
//  Data+Extensions.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import Foundation

extension String {
    
    func webSafeBase64DecodedData() -> Data? {
        let base64EncodedString = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        var padding = ""
        let rest = base64EncodedString.count % 4

        if rest != 0 {
            padding = String(repeating: "=", count: 4 - rest)
        }

        return Data(base64Encoded: base64EncodedString.appending(padding))
    }
}

extension Data {
    
    func webSafeBase64EncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    var hexString: String {
        self.map({ String(format: "%02x", $0) }).joined()
    }
}
