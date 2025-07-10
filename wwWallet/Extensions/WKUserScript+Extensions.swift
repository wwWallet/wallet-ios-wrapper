//
//  WKUserScript+Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 21.04.25.
//

import WebKit

extension WKUserScript {

    static let bluetoothScript = bundledScript(named: "WebBluetooth")

    static let nativeWrapperScript = bundledScript(named: "NativeWrapper")

    static let sharedScript = bundledScript(named: "Shared")


    class func bundledScript(named name: String, _ data: [String: String] = [:]) -> WKUserScript? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              var content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        for key in data.keys {
            content = content.replacingOccurrences(of: "{{ \(key) }}", with: data[key] ?? "")
        }

        return .init(source: content, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
}
