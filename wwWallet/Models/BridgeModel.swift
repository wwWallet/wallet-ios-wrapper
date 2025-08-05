//
//  BridgeModel.swift
//  wwWallet
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

    @MainActor
    var loadURLCallback: ((URL) -> Void)?

    private(set) var pin: String?

    func openUrl(_ url: URL) {
        Task {
            await MainActor.run {
                loadURLCallback?(url)
            }
        }
    }

    func didReceiveCreate(_ message: WKScriptMessage) async throws -> [String: String?] {
        do {
            let request: CreateRequestWrapper = try await message.decode()

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
                    await acquirePin(message)

                    // User cancelled.
                    if pin?.isEmpty ?? true {
                        return [:]
                    }

                    return try await didReceiveCreate(message)
                }
            }

            if error.code == 0x19 {
                // Special treatment for unclear reasons.
                throw Errors.error0x19
            }

            throw error
        }
    }

    func didReceiveGet(_ message: WKScriptMessage) async throws -> [String: String?] {
        do {
            print("\(await message.stringBody ?? "(nil)")")

            let request: GetRequestWrapper = try await message.decode()

            // If wwWallet wants user verification, we *do need to use a PIN*.
            // For subsequent calls, we then have the PIN available.
            // See https://developers.yubico.com/WebAuthn/WebAuthn_Developer_Guide/User_Presence_vs_User_Verification.html
            let needsPin = request.request.userVerification?.lowercased() == "required"

            // At the first time, this PIN will be empty, so we throw right away
            // in order to trigger the PIN entry UI.
            if needsPin && (pin?.isEmpty ?? true) {
                // Error message unneeded, because it will not be shown when we throw before session initialization.
                throw NSError(domain: "com.yubico", code: 49)
            }

            let conn = await connection.connect()

            let session = try await conn.fido2Session()

            // For subsequent calls, we have the PIN available and try to verify it.
            if needsPin {
                try await session.verifyPin(pin ?? "")
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

            if error.domain == "com.yubico" {
                if [
                    49 /* "PIN is invalid." */,
                    54 /* "PIN is required for the selected operation." */
                ].contains(error.code)
                {
                    await acquirePin(message)

                    // User cancelled.
                    if pin?.isEmpty ?? true {
                        return [:]
                    }

                    return try await didReceiveGet(message)
                }
            }

            throw error
        }
    }

    func loginStatusChanged(_ message: WKScriptMessage) async throws {
        if await message.stringBody == "unlocked" {
            try Lock.unlock()
        }
        else {
            try Lock.lock()
        }
    }

    private func acquirePin(_ message: WKScriptMessage) async {
        do {
            let value = try await message.webView?.callAsyncJavaScript(
                "return prompt(\"\(NSLocalizedString("Please enter your FIDO2/WebAuthn PIN.", comment: ""))\", \"\(WebView.isSecureTextEntry)\")",
                contentWorld: message.world)

            pin = value as? String
        }
        catch {
            pin = nil
        }
    }
}
