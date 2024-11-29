//
//  WebView.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
@preconcurrency import WebKit

class CreateMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    let model: BridgeModel
    
    public init(model: BridgeModel) {
        self.model = model
    }
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        
        let jsonString = message.body as! String
        let jsonData = jsonString.data(using: .utf8)!
        
        guard let jsonDictionary = try! JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            fatalError()
        }
        model.didReceiveCreate(message: jsonDictionary, replyHandler: replyHandler)
    }
}


class GetMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    let model: BridgeModel
    
    public init(model: BridgeModel) {
        self.model = model
    }
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        
        let jsonString = message.body as! String
        let jsonData = jsonString.data(using: .utf8)!
        
        guard let jsonDictionary = try! JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            fatalError()
        }
        model.didReceiveGet(message: jsonDictionary, replyHandler: replyHandler)
    }
}


struct WebView: UIViewRepresentable {
    let url: URL
    let model: BridgeModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, model: model)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        
        let url: URL
        let model: BridgeModel
        let createMessageHandler: CreateMessageHandler
        let getMessageHandler: GetMessageHandler
        private let webauthnGetInterface = "__webauthn_get_interface__"
        private let webauthnCreateInterface = "__webauthn_create_interface__"

        init(url: URL, model: BridgeModel) {
            self.url = url
            self.model = model
            self.createMessageHandler = CreateMessageHandler(model: model)
            self.getMessageHandler = GetMessageHandler(model: model)
        }
        
        lazy var wkWebView: WKWebView = {
            let userScript = WKUserScript(source: String.bridgeJavaScript,
                                          injectionTime: .atDocumentEnd,
                                          forMainFrameOnly: false)
            let userContentController = WKUserContentController()
            if UserDefaults.standard.bool(forKey: "use_yubikey") {
                userContentController.addUserScript(userScript)
            }
            userContentController.addScriptMessageHandler(createMessageHandler, contentWorld: .page, name: webauthnCreateInterface)
            userContentController.addScriptMessageHandler(getMessageHandler, contentWorld: .page, name: "__webauthn_get_interface__")
            let configuration = WKWebViewConfiguration()
            configuration.limitsNavigationsToAppBoundDomains = true;
            configuration.userContentController = userContentController
            let wkWebView = WKWebView(frame: CGRect.zero, configuration: configuration)
            model.loadURLCallback = { url in
                wkWebView.load(URLRequest(url: url))
            }
            let request = URLRequest(url: url)
            wkWebView.isInspectable = true
            wkWebView.navigationDelegate = self
            wkWebView.load(request)
            return wkWebView
        }()
        
        // WKNavigationDelegate
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let requestUrl = navigationAction.request.url {
                if requestUrl.scheme == "eid" {
                    // Open the AusweisApp
                    UIApplication.shared.open(requestUrl)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        return context.coordinator.wkWebView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
    }
}


extension String {
    static var bridgeJavaScript: String {
        let path = Bundle.main.path(forResource: "BridgeJavaScript", ofType: "js")
        return try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
    }
}


struct JSONCodingKeys: CodingKey {
    var stringValue: String

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int?

    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}


extension KeyedDecodingContainer {

    func decode(_ type: Dictionary<String, Any>.Type, forKey key: K) throws -> Dictionary<String, Any> {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode(type)
    }

    func decodeIfPresent(_ type: Dictionary<String, Any>.Type, forKey key: K) throws -> Dictionary<String, Any>? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    func decode(_ type: Array<Any>.Type, forKey key: K) throws -> Array<Any> {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        return try container.decode(type)
    }

    func decodeIfPresent(_ type: Array<Any>.Type, forKey key: K) throws -> Array<Any>? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    func decode(_ type: Dictionary<String, Any>.Type) throws -> Dictionary<String, Any> {
        var dictionary = Dictionary<String, Any>()

        for key in allKeys {
            if let boolValue = try? decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            } else if let stringValue = try? decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            } else if let intValue = try? decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            } else if let doubleValue = try? decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            } else if let nestedDictionary = try? decode(Dictionary<String, Any>.self, forKey: key) {
                dictionary[key.stringValue] = nestedDictionary
            } else if let nestedArray = try? decode(Array<Any>.self, forKey: key) {
                dictionary[key.stringValue] = nestedArray
            }
        }
        return dictionary
    }
}

extension UnkeyedDecodingContainer {

    mutating func decode(_ type: Array<Any>.Type) throws -> Array<Any> {
        var array: [Any] = []
        while isAtEnd == false {
            // See if the current value in the JSON array is `null` first and prevent infite recursion with nested arrays.
            if try decodeNil() {
                continue
            } else if let value = try? decode(Bool.self) {
                array.append(value)
            } else if let value = try? decode(Double.self) {
                array.append(value)
            } else if let value = try? decode(String.self) {
                array.append(value)
            } else if let nestedDictionary = try? decode(Dictionary<String, Any>.self) {
                array.append(nestedDictionary)
            } else if let nestedArray = try? decode(Array<Any>.self) {
                array.append(nestedArray)
            }
        }
        return array
    }

    mutating func decode(_ type: Dictionary<String, Any>.Type) throws -> Dictionary<String, Any> {

        let nestedContainer = try self.nestedContainer(keyedBy: JSONCodingKeys.self)
        return try nestedContainer.decode(type)
    }
}

