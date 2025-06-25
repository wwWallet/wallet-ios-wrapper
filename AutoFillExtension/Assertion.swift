//
//  Assertion.swift
//  AutoFillExtension
//
//  Created by Benjamin Erhart on 25.06.25.
//

import Foundation
import CryptoKit
import AuthenticationServices

/**
 This is taken from https://github.com/tucur-prg/password-manager/tree/main/provider
 */
class Assertion {

    class func makeAssertionCredential(
        rpId: String,
        flags: AuthenticatorDataFlags? = nil,
        passkey: Passkey,
        clientDataHash: Data)
    throws -> ASPasskeyAssertionCredential
    {
        let assertion = try Assertion(rpId: rpId, flags: flags)

        guard let key = passkey.privateKey else {
            throw Errors.couldNotFindPublicKey
        }

        var message = Data()
        message.append(assertion.raw)
        message.append(clientDataHash)

        let signature = try key.sign(message)

        return .init(
            userHandle: passkey.userHandle,
            relyingParty: rpId,
            signature: signature,
            clientDataHash: clientDataHash,
            authenticatorData: assertion.raw,
            credentialID: passkey.keyId)
    }

    private(set) var raw = Data()


    init(rpId: String, flags: AuthenticatorDataFlags? = nil, signatureCount: Int = 0) throws {
        guard let rpId = rpId.data(using: .utf8) else {
            throw Errors.couldNotEncodeRpId
        }

        raw.append(Data(SHA256.hash(data: rpId)))

        var flags = try flags ?? .init()
        flags.UP = true

        raw.append(flags.value)

        var signatureCount = UInt32(signatureCount).bigEndian
        let signatureCountData = Data(bytes: &signatureCount, count: MemoryLayout<UInt32>.size)
        raw.append(signatureCountData)
    }
}
