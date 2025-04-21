//
//  WebView.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
@preconcurrency import WebKit
import CoreBluetooth

class MessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    
    let handler: (WKScriptMessage, (@escaping @MainActor @Sendable (Any?, String?) -> Void)) -> Void
    
    init(handler: @escaping @MainActor @Sendable (WKScriptMessage, @escaping (Any?, String?) -> Void) -> Void) {
        self.handler = handler
    }
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage,
                               replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
        
        self.handler(message, replyHandler)
    }
}

enum PasskeyType {
    case builtin, yubikey
}

struct WebView: UIViewRepresentable {
    let url: URL
    let model: BridgeModel
    let passkeyType: PasskeyType
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, model: model, passkeyType: passkeyType)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        let url: URL
        let model: BridgeModel
        let passkeyType: PasskeyType
        let bleServer = BLEServer.shared
        let bleClient = BLEClient.shared
        
        init(url: URL, model: BridgeModel, passkeyType: PasskeyType) {
            self.url = url
            self.model = model
            self.passkeyType = passkeyType
        }
        
        lazy var wkWebView: WKWebView = {
            let userContentController = WKUserContentController()
            
            
            let sharedScript = WKUserScript(source: String.sharedJavaScript,
                                          injectionTime: .atDocumentStart,
                                          forMainFrameOnly: false)
            userContentController.addUserScript(sharedScript)
            if passkeyType == .yubikey {
                let bridgeScript = WKUserScript(source: String.bridgeJavaScript,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false)
                userContentController.addUserScript(bridgeScript)
                // Webauthn
                let createMessageHandler = MessageHandler { [weak self] message, replyHandler in
                    Task {
                        do {
                            let reply = try await self?.model.didReceiveCreate(message)
                            replyHandler(reply, nil)
                        }
                        catch {
                            replyHandler(nil, error.localizedDescription)
                        }
                    }
                }
                userContentController.addScriptMessageHandler(createMessageHandler, contentWorld: .page, name: "__webauthn_create_interface__")
                
                let getMessageHandler = MessageHandler { [weak self] message, replyHandler in
                    Task {
                        do {
                            let reply = try await self?.model.didReceiveGet(message)
                            replyHandler(reply, nil)
                        }
                        catch {
                            replyHandler(nil, error.localizedDescription)
                        }
                    }
                }
                userContentController.addScriptMessageHandler(getMessageHandler, contentWorld: .page, name: "__webauthn_get_interface__")
            }
            let nativeWrapperScript = WKUserScript(source: String.nativeWrapperJavaScript,
                                          injectionTime: .atDocumentStart,
                                          forMainFrameOnly: false)
            userContentController.addUserScript(nativeWrapperScript)
            

            // BLE hooks
            let bleStatusMessageHandler = MessageHandler { [weak self] message, replyHandler in
                print("Status message: \(message)")
            }
            userContentController.addScriptMessageHandler(bleStatusMessageHandler, contentWorld: .page, name: "__bluetoothStatus__")
            
            let bleTerminateMessageHandler = MessageHandler { [weak self] message, replyHandler in
                print("⚙️ Terminate message: \(message.body)")
                self?.bleClient.disconnect()
                self?.bleServer.disconnect()
                replyHandler(true, nil)
            }
            userContentController.addScriptMessageHandler(bleTerminateMessageHandler, contentWorld: .page, name: "__bluetoothTerminate__")
            
            let bleCreateServerMessageHandler = MessageHandler { [weak self] message, replyHandler in
                print("⚙️ Create server message: \(message.body)")
            }
            userContentController.addScriptMessageHandler(bleCreateServerMessageHandler, contentWorld: .page, name: "__bluetoothCreateServer__")
            
            let bleCreateClientMessageHandler = MessageHandler { [weak self] message, replyHandler in
                print("⚙️ Create client message: \(message.body)")
                guard let uuidString: String = message.parseJSON() else { replyHandler(nil, "Not a valid UUID string."); return }
                let uuid = CBUUID(string: uuidString)
                self?.bleClient.startScanning(for: uuid, completionHandler: replyHandler)
            }
            userContentController.addScriptMessageHandler(bleCreateClientMessageHandler, contentWorld: .page, name: "__bluetoothCreateClient__")
            
            let bleSendToServerMessageHandler = MessageHandler { [weak self] message, replyHandler in
                print("⚙️ Send to server message: \(message.body)")
                let jsonString = message.body as! String
                let jsonData = (jsonString.dropFirst().dropLast()).data(using: .utf8)!
                guard let result = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? [UInt8] else { return }
                let data = Data(result)
                self?.bleClient.sendToServer(data: data, completionHandler: replyHandler)
            }
            userContentController.addScriptMessageHandler(bleSendToServerMessageHandler, contentWorld: .page, name: "__bluetoothSendToServer__")
            
            let bleSendToClientMessageHandler = MessageHandler { [weak self] message, replyHandler in
                print("⚙️ Send to client message: \(message.body)")
            }
            userContentController.addScriptMessageHandler(bleSendToClientMessageHandler, contentWorld: .page, name: "__bluetoothSendToClient__")
            
            let bleReceiveFromClientMessageHandler = MessageHandler { [weak self] message, replyHandler in
                print("⚙️ Receive from client message: \(message.body)")
            }
            userContentController.addScriptMessageHandler(bleReceiveFromClientMessageHandler, contentWorld: .page, name: "__bluetoothReceiveFromClient__")
            
            let bleReceiveFromServerMessageHandler = MessageHandler { [weak self] _, replyHandler in
                print("⚙️ Receive from server")
                self?.bleClient.receiveFromServer(completionHandler: replyHandler)
            }
            userContentController.addScriptMessageHandler(bleReceiveFromServerMessageHandler, contentWorld: .page, name: "__bluetoothReceiveFromServer__")
            
            let configuration = WKWebViewConfiguration()
            configuration.limitsNavigationsToAppBoundDomains = true;
            configuration.userContentController = userContentController
            let wkWebView = WKWebView(frame: CGRect.zero, configuration: configuration)
            model.loadURLCallback = { url in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    wkWebView.load(URLRequest(url: url))
                }
            }
            let request = URLRequest(url: url)
            wkWebView.isInspectable = true
            wkWebView.navigationDelegate = self
            wkWebView.uiDelegate = self
            wkWebView.load(request)
            return wkWebView
        }()
        

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let requestUrl = navigationAction.request.url {
                if requestUrl.scheme == "eid" {
                    // Open the AusweisApp
                    UIApplication.shared.open(requestUrl)

                    return decisionHandler(.cancel)
                }
            }

            decisionHandler(.allow)
        }


        // MARK: WKUIDelegate

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

                alert.addAction(.init(title: NSLocalizedString("Ok", comment: ""), style: .default) { _ in
                    continuation.resume()
                })

                UIApplication.shared.keyWindow?.rootViewController?.top.present(alert, animated: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo
        ) async -> String? {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

                alert.addAction(.init(title: NSLocalizedString("Ok", comment: ""), style: .default) { _ in
                    continuation.resume(returning: alert.textFields?.first?.text)
                })

                alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    continuation.resume(returning: nil)
                })

                alert.addTextField { tf in
                    tf.placeholder = defaultText
                }

                UIApplication.shared.keyWindow?.rootViewController?.top.present(alert, animated: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async -> Bool {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

                alert.addAction(.init(title: NSLocalizedString("Ok", comment: ""), style: .default) { _ in
                    continuation.resume(returning: true)
                })

                alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    continuation.resume(returning: false)
                })

                UIApplication.shared.keyWindow?.rootViewController?.top.present(alert, animated: true)
            }
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        return context.coordinator.wkWebView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.uiDelegate = context.coordinator
    }
}


extension String {
    static var sharedJavaScript: String {
        let path = Bundle.main.path(forResource: "SharedJavaScript", ofType: "js")
        return try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
    }
    
    static var bridgeJavaScript: String {
        let path = Bundle.main.path(forResource: "BridgeJavaScript", ofType: "js")
        return try! String(contentsOfFile: path!, encoding: String.Encoding.utf8)
    }
    
    static var nativeWrapperJavaScript: String {
        let path = Bundle.main.path(forResource: "NativeWrapperJavaScript", ofType: "js")
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

