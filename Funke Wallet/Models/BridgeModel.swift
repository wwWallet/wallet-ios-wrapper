//
//  BridgeModel.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-29.
//


import SwiftUI
import YubiKit
import WebKit

@Observable class BridgeModel {

    var receivedMessage: String?
    var sentMessage: String?
    let connection = YubiKeyConnection()

    var loadURLCallback: ((URL) -> Void)?

    func openUrl(_ url: URL) {
        loadURLCallback?(url)
    }

    func didReceiveCreate(_ message: WKScriptMessage, pin: String? = nil) async throws -> [String: String?] {
        do {
            guard let data = await (message.body as? String)?.data(using: .utf8) else {
                throw Errors.cannotDecodeMessage
            }

            let request = try JSONDecoder().decode(CreateRequestWrapper.self, from: data)

            let conn = await connection.connect()

            let session = try await conn.fido2Session()

            if let pin = pin, !pin.isEmpty {
                try await session.verifyPin(pin)
            }

            let r = request.request

            guard let clientDataHash = r.clientData?.clientDataHash else {
                throw Errors.cannotCreateClientDataHash
            }

            guard let user = r.user.entity else {
                throw Errors.cannotCreateUserEntity
            }

            // TODO: This thing throws NSExceptions like crazy all over the place in
            //      threads, which are uncatchable and hence crash the app.
            //      This needs to change.
            let (response, extensionResult) = try await session.makeCredential(
                with: clientDataHash,
                rp: r.rp.entity,
                user: user,
                pubKeyCredParams: r.pubKeyCredParams.map({ $0.param }),
                excludeList: r.excludeCredentials?.compactMap({ $0.descriptor }),
                options: r.options,
                extensions: r.extensions)

            let credentials = Credentials(r.clientData!, response, extensionResult)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "create")), encoding: .utf8)

            YubiKitManager.shared.stopNFCConnection()

            return ["data": json]
        }
        catch {
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)

            let error = error as NSError

            if error.domain == "com.yubico" {
                if [
                    49 /* "PIN is invalid." */,
                    54 /* "PIN is required for the selected operation." */
                ].contains(error.code)
                {
                    return try await didReceiveCreate(message, pin: getPin(message))
                }
            }

            if error.code == 0x19 {
                // Special treatment for unclear reasons.
                throw Errors.error0x19
            }

            throw error
        }
    }

    func didReceiveGet(_ message: WKScriptMessage, pin: String? = "123456") async throws -> [String: String?] {
        do {
            guard let data = await (message.body as? String)?.data(using: .utf8) else {
                throw Errors.cannotDecodeMessage
            }

            let request = try JSONDecoder().decode(GetRequestWrapper.self, from: data)

            let conn = await connection.connect()

            let session = try await conn.fido2Session()

            if let pin = pin, !pin.isEmpty {
                try await session.verifyPin(pin)
            }

            let r = request.request

            guard let clientDataHash = r.clientData?.clientDataHash else {
                throw Errors.cannotCreateClientDataHash
            }

            // TODO: This thing throws NSExceptions like crazy all over the place in
            //      threads, which are uncatchable and hence crash the app.
            //      This needs to change.
            let response = try await session.getAssertion(
                with: clientDataHash,
                rpId: r.rpId,
                allowList: r.allowCredentials?.compactMap { $0.descriptor },
                extensions: r.extensions)

            let credentials = Credentials(r.clientData!, response)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "get")), encoding: .utf8)

            YubiKitManager.shared.stopNFCConnection()

            return ["data": json]
        }
        catch {
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)

            let error = error as NSError

            // TODO: Nice try, but this doesn't work as expected:
            //      When used without a PIN, this method still succeeds.
            //      How the hell to detect, when a PIN entry is necessary?
            if error.domain == "com.yubico" {
                if [
                    49 /* "PIN is invalid." */,
                    54 /* "PIN is required for the selected operation." */
                ].contains(error.code)
                {
                    return try await didReceiveGet(message, pin: getPin(message))
                }
            }

            throw error
        }
    }

    private func getPin(_ message: WKScriptMessage) async -> String? {
        do {
            let value = try await message.webView?.callAsyncJavaScript(
                "return prompt(\"\(NSLocalizedString("Please enter your FIDO2/WebAuthn PIN.", comment: ""))\")",
                contentWorld: message.world)

            return value as? String
        }
        catch {
            return nil
        }
    }
}
