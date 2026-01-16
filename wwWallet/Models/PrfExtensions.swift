//
//  PrfExtensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 16.01.26.
//

import Foundation
import YubiKit

/**
 Struct to manage PRF extension handling.
 */
struct PrfExtensions {

    private let extensions: [String: PrfExtension]


    /**
     - parameter session: The CTAP2 session to use for key agreement.
     - parameter extensions: An opaque dictionary of extension parameters received from the web app.
         Should be coming either from ``GetRequest.extensions`` or ``CreateRequest.extensions``.
     - parameter credentials: For `getAssertion` requests, should be the allowed credentials list from the server:
        ``GetRequest.allowCredentials``, For `makeCredential` requests, should be `nil`.
     */
    init(_ session: CTAP2.Session, _ extensions: [String: Any]?, _ credentials: [Credentials]? = nil) async throws {
        var cids = credentials?.compactMap { $0.id } ?? []
        cids.append("")

        var result = [String: PrfExtension]()

        for cid in cids {
            if let secrets = Self.getSecrets(from: extensions, for: cid) {
                result[cid] = try await PrfExtension(session, secrets.first, secrets.second)
            }
        }

        self.extensions = result
    }


    /**
     Creates proper PRF extension input for the YubiKit for `makeCredential` requests using secrets material which should have
     been found in the `eval` key of the `extensions` dictionary.
     */
    func makeCredentialInput() throws -> [CTAP2.Extension.MakeCredential.Input] {
        guard let e = extensions[""] else {
            return []
        }

        return [try e.prf.makeCredential.input(first: e.firstSecret, second: e.secondSecret)]
    }

    /**
     Creates proper PRF extension input for the YubiKit for `getAssertion` requests using secrets material which should have
     been found in the `evalByCredential` key of the `extensions` dictionary.

     - returns: For each allowed key a PRF extension, if secrets were found for that key.
     */
    func getAssertionInput() throws -> [CTAP2.Extension.GetAssertion.Input] {
        try extensions.map { (_, v) in
            try v.prf.getAssertion.input(first: v.firstSecret, second: v.secondSecret)
        }
    }

    /**
     Decrypts the  ``CTAP2.MakeCredential.Response`` from the YubiKey with the symmetric key material stored when creating the input.
     */
    func makeCredentialOutput(from response: CTAP2.MakeCredential.Response) throws -> WebAuthn.Extension.PRF.MakeCredentialOperations.Result? {
        try extensions[""]?.prf.makeCredential.output(from: response)
    }

    /**
     Decrypts the  ``CTAP2.GetAssertion.Response`` from the YubiKey with the symmetric key material stored when creating the input.
     */
    func getAssertionOutput(from response: CTAP2.GetAssertion.Response) throws -> WebAuthn.Extension.PRF.Secrets? {
        let cid = response.credential?.id.webSafeBase64EncodedString()

        return try (extensions[cid ?? ""] ?? extensions[""])?.prf.getAssertion.output(from: response)
    }


    /**
     Find PRF secrets in an opaque extensions data structure.

     If you provide a Credentials ID, the `evalByCredential` key is evaluated, if not, secrets from the default `eval` key are returned.

     - parameter extensions: The opaque extensions data structure
     - parameter cid: Optional Credentials ID to search secrets for

     - returns: web-safe BASE64-encoded first and (optional) second secret
     */
    private static func getSecrets(from extensions: [String: Any]?, for cid: String? = nil) -> (first: Data, second: Data?)? {
        guard let prf = extensions?["prf"] as? [String: Any]
        else {
            return nil
        }

        var secrets: [String: String]? = nil

        if let cid, !cid.isEmpty {
            guard let evalByCred = prf["evalByCredential"] as? [String: [String: String]] else {
                return nil
            }

            secrets = evalByCred[cid]
        }
        else {
            secrets = prf["eval"] as? [String: String]
        }

        guard let first = secrets?["first"]?.webSafeBase64DecodedData() else {
            return nil
        }

        let second = secrets?["second"]?.webSafeBase64DecodedData()

        return (first: first, second: second)
    }
}

/**
 Structure to store symmetric secrets encryption key and secrets.
 */
struct PrfExtension {

    let prf: WebAuthn.Extension.PRF
    let firstSecret: Data
    let secondSecret: Data?


    /**
     - parameter session: The CTAP2 session to use for key agreement.
     - parameter firstSecret: The first secret found in ``GetRequest.extensions`` or ``CreateRequest.extensions``.
     - parameter secondSecret: Optional second secret found in ``GetRequest.extensions`` or ``CreateRequest.extensions``.
     */
    init(_ session: CTAP2.Session, _ firstSecret: Data, _ secondSecret: Data?) async throws {
        prf = try await WebAuthn.Extension.PRF(session: session)

        self.firstSecret = firstSecret
        self.secondSecret = secondSecret
    }
}
