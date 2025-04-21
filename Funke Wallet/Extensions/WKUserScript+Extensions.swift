//
//  WKUserScript+Extensions.swift
//  Funke Wallet
//
//  Created by Benjamin Erhart on 21.04.25.
//

import WebKit

extension WKUserScript {

    static let sharedScript: WKUserScript? = bundledScript(named: "Shared")

    static let bridgeScript: WKUserScript? = bundledScript(named: "Bridge")

    static let nativeWrapperScript: WKUserScript? = bundledScript(named: "NativeWrapper")

    
    private class func bundledScript(named name: String) -> WKUserScript? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }
        
        return .init(source: content, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
}
