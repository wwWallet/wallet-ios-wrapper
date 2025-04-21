//
//  WebView.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
@preconcurrency import WebKit
import CoreBluetooth
import OSLog

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
        
        private let log = Logger(with: Coordinator.self)

        init(url: URL, model: BridgeModel, passkeyType: PasskeyType) {
            self.url = url
            self.model = model
            self.passkeyType = passkeyType
        }
        
        lazy var wkWebView: WKWebView = {
            let ucc = WKUserContentController()
            
            ucc.addUserScript(.sharedScript!)


            if passkeyType == .yubikey {
                ucc.addUserScript(.bridgeScript!)

                // Webauthn
                ucc.addPageHandler(named: "__webauthn_create_interface__") { [weak self] message in
                    return try await self?.model.didReceiveCreate(message)
                }

                ucc.addPageHandler(named: "__webauthn_get_interface__") { [weak self] message in
                    return try await self?.model.didReceiveGet(message)
                }
            }

            ucc.addUserScript(.nativeWrapperScript!)


            // BLE hooks
            ucc.addPageHandler(named: "__bluetoothStatus__") { [weak self] message in
                self?.log.debug("Status message: \(message)")

                return nil
            }

            ucc.addPageHandler(named: "__bluetoothTerminate__") {[weak self] message in
                self?.log.debug("⚙️ Terminate message: \(message.body as? String ?? "(unknown encoding)")")

                self?.bleClient.disconnect()
                self?.bleServer.disconnect()

                return true
            }

            ucc.addPageHandler(named: "__bluetoothCreateServer__") { [weak self] message in
                self?.log.debug("⚙️ Create server message: \(message.body as? String ?? "(unknown encoding)")")

                return nil
            }

            ucc.addPageHandler(named: "__bluetoothCreateClient__") { [weak self] message in
                self?.log.debug("⚙️ Create client message: \(message.body as? String ?? "(unknown encoding)")")

                guard let uuidString: String = message.parseJSON() else {
                    throw Errors.invalidUuid
                }

                return await self?.bleClient.startScanning(for: CBUUID(string: uuidString))
            }

            ucc.addPageHandler(named: "__bluetoothSendToServer__") { [weak self] message in
                self?.log.debug("⚙️ Send to server message: \(message.body as? String ?? "(unknown encoding)")")

                guard let jsonString = message.body as? String,
                      let jsonData = jsonString.dropFirst().dropLast().data(using: .utf8),
                      let result = try? JSONSerialization.jsonObject(with: jsonData, options: [.allowFragments]) as? [UInt8]
                else {
                    return nil
                }

                return await self?.bleClient.sendToServer(data: Data(result))
            }

            ucc.addPageHandler(named: "__bluetoothSendToClient__") { [weak self] message in
                self?.log.debug("⚙️ Send to client message: \(message.body as? String ?? "(unknown encoding)")")

                return nil
            }

            ucc.addPageHandler(named: "__bluetoothReceiveFromClient__") { [weak self] message in
                self?.log.debug("⚙️ Receive from client message: \(message.body as? String ?? "(unknown encoding)")")

                return nil
            }

            ucc.addPageHandler(named: "__bluetoothReceiveFromServer__") { [weak self] _ in
                self?.log.debug("⚙️ Receive from server")

                return await self?.bleClient.receiveFromServer()
            }


            let configuration = WKWebViewConfiguration()
            configuration.limitsNavigationsToAppBoundDomains = true
            configuration.userContentController = ucc

            let wkWebView = WKWebView(frame: .zero, configuration: configuration)

            model.loadURLCallback = { url in
                wkWebView.load(URLRequest(url: url))
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
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
        {
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
