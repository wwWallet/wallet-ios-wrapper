//
//  WKUserScript+Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 21.04.25.
//

import WebKit

extension WKUserScript {

    static let bluetoothScript = bundledScript(named: "WebBluetooth")

    static let bridgeScript = bundledScript(named: "Bridge")

    static let nativeWrapperScript = bundledScript(named: "NativeWrapper")

    static let sharedScript = bundledScript(named: "Shared")


    private class func bundledScript(named name: String) -> WKUserScript? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }
        
        return .init(source: content, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
}
