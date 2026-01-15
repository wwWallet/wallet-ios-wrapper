//
//  WebAuthnClientData.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 09.01.26.
//

import Foundation
import CryptoKit

class WebAuthnClientData: Codable {

    enum `Type`: String, Codable {
        case create = "webauthn.create"
        case get = "webauthn.get"
    }

    /**
     The operation type the Client Data will be used for. This property has the value `create`
     when creating new credentials and `get when getting an assertion from an existing credential.
     */
    let type: `Type`

    /**
     The challenge received from the WebAuthN Relying Party as web-safe BASE64 encoded string.
     */
    let challenge: String


    /**
     This member contains the fully qualified origin of the requester, as provided to the authenticator by the client.
     */
    let origin: String

    /**
     This is a derived property which returns the clientDataJson as defined by WebAuthN:
     https://www.w3.org/TR/webauthn/#sec-client-data
     */
    var jsonData: Data {
        get throws {
            try JSONEncoder().encode(self)
        }
    }

    /**
     This is a derived property which returns the SHA-256 of the `jsonData`.
     */
    var clientDataHash: Data {
        get throws {
            Data(SHA256.hash(data: try jsonData))
        }
    }


    init?(type: `Type`, challenge: String, origin: String) {
        // For an unknown reason, we cannot just pass the string through, but need to reencode,
        // to make sure, e.g. there are no "=" at the end. Otherwise, authentication will fail.
        guard let challenge = challenge.webSafeBase64DecodedData()?.webSafeBase64EncodedString() else {
            return nil
        }

        self.type = type
        self.challenge = challenge
        self.origin = origin
    }
}
