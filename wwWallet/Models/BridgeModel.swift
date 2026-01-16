//
//  BridgeModel.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//


import SwiftUI
import YubiKit
import WebKit
import OSLog

@Observable class BridgeModel {

    var receivedMessage: String?
    var sentMessage: String?

    @MainActor
    var loadURLCallback: ((URL) -> Void)?

    private(set) var pin: String?


    private let log: Logger = Logger(for: BridgeModel.self)


    func openUrl(_ url: URL) {
        Task {
            await MainActor.run {
                loadURLCallback?(url)
            }
        }
    }

    func didReceiveCreate(_ message: WKScriptMessage) async throws -> [String: String?] {
        var conn: NFCSmartCardConnection? = nil

        do {
            let sb = await message.stringBody
            log.debug("\(sb ?? "(nil)")")

            let request: CreateRequestWrapper = try await message.decode()

            conn = try await NFCSmartCardConnection.makeConnection()

            let session = try await CTAP2.Session.makeSession(connection: conn!)

            let r = request.request
            var token: CTAP2.ClientPin.Token? = nil

            if let pin = pin, !pin.isEmpty {
                token = try await session.getPinUVToken(using: .pin(pin), permissions: .makeCredential, rpId: r.rp.id)
            }

            guard let clientDataHash = try r.clientData?.clientDataHash else {
                throw Errors.cannotCreateClientDataHash
            }

            guard let user = r.user.entity else {
                throw Errors.cannotCreateUserEntity
            }

            let prfs = try await PrfExtensions(session, r.extensions)
            let extensions = try prfs.makeCredentialInput()

            let response = try await session.makeCredential(
                parameters: .init(
                    clientDataHash: clientDataHash,
                    rp: r.rp.entity,
                    user: user,
                    pubKeyCredParams: r.pubKeyCredParams.map({ $0.algorithm }),
                    excludeList: r.excludeCredentials?.compactMap({ $0.descriptor }),
                    extensions: extensions,
                    options: r.options
                ),
                pinToken: token).value

            let credentials = try Credentials(r.clientData!, response, prfs)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "create")), encoding: .utf8)

            await conn?.close()

            log.debug("\(json ?? "(nil)")")

            return ["data": json]
        }
        catch {
            switch error {
            case CTAP2.SessionError.ctapError(let error, source: _):
                await conn?.close(error: error)

                switch error {
                case CTAP2.Error.pinInvalid, CTAP2.Error.puatRequired:
                    await acquirePin(message)

                    // User cancelled.
                    if pin?.isEmpty ?? true {
                        return [:]
                    }

                    return try await didReceiveCreate(message)

                case CTAP2.Error.credentialExcluded:
                    // Special treatment for unclear reasons.
                    throw Errors.error0x19

                default:
                    throw error
                }

            default:
                await conn?.close(error: error)

                throw error
            }
        }
    }

    func didReceiveGet(_ message: WKScriptMessage) async throws -> [String: String?] {
        var conn: NFCSmartCardConnection? = nil

        do {
            let sb = await message.stringBody
            log.debug("\(sb ?? "(nil)")")

            let request: GetRequestWrapper = try await message.decode()

            // If wwWallet wants user verification, we *do need to use a PIN*.
            // For subsequent calls, we then have the PIN available.
            // See https://developers.yubico.com/WebAuthn/WebAuthn_Developer_Guide/User_Presence_vs_User_Verification.html
            let needsPin = request.request.userVerification?.lowercased() == "required"

            // At the first time, this PIN will be empty, so we throw right away
            // in order to trigger the PIN entry UI.
            if needsPin && (pin?.isEmpty ?? true) {
                // Error message unneeded, because it will not be shown when we throw before session initialization.
                throw CTAP2.SessionError.ctapError(CTAP2.Error.puatRequired, source: .here())
            }

            conn = try await NFCSmartCardConnection.makeConnection()

            let session = try await CTAP2.Session.makeSession(connection: conn!)

            let r = request.request
            var token: CTAP2.ClientPin.Token? = nil

            // For subsequent calls, we have the PIN available and try to verify it.
            if needsPin {
                token = try await session.getPinUVToken(using: .pin(pin ?? ""), permissions: .getAssertion, rpId: r.rpId)
            }

            guard let clientDataHash = try r.clientData?.clientDataHash else {
                throw Errors.cannotCreateClientDataHash
            }

            let prfs = try await PrfExtensions(session, r.extensions, r.allowCredentials)
            let extensions = try prfs.getAssertionInput()

            let response = try await session.getAssertion(
                parameters: .init(
                    rpId: r.rpId,
                    clientDataHash: clientDataHash,
                    allowList: r.allowCredentials?.compactMap({ $0.descriptor }),
                    extensions: extensions
                ),
                pinToken: token).value

            let credentials = try Credentials(r.clientData!, response, prfs)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "get")), encoding: .utf8)

            log.debug("\(json ?? "(nil)")")

            await conn?.close()

            return ["data": json]
        }
        catch {
            switch error {
            case CTAP2.SessionError.ctapError(let error, source: _):
                await conn?.close(error: error)

                log.error("\(error)")

                switch error {
                case CTAP2.Error.pinInvalid, CTAP2.Error.puatRequired:
                    await acquirePin(message)

                    // User cancelled.
                    if pin?.isEmpty ?? true {
                        return [:]
                    }

                    return try await didReceiveGet(message)

                default:
                    throw error
                }

            default:
                await conn?.close(error: error)

                log.error("\(error)")

                throw error
            }
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
