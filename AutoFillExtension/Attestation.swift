//
//  Attestation.swift
//  AutoFillExtension
//
//  Created by Benjamin Erhart on 05.06.25.
//

import Foundation
import CryptoKit
import SwiftCBOR
import AuthenticationServices

/**
 This is taken from https://github.com/Yubico/java-webauthn-server/blob/c8a5523bca61fd7eb1c6a5f6af15c354159a7966/webauthn-server-core/src/test/scala/com/yubico/webauthn/TestAuthenticator.scala#L559-L581
 */
class Attestation {

    /**
     Autheticator Attestation GUID
     */
    static let aaguid = UUID(uuidString: "0a073192-1e1e-4d90-ade2-0fc6d19ceb03")!


    class func createRegistrationCredential(
        credentialId: Data,
        privateKey: SecKey,
        rpId: String,
        authenticatorExtensions: CBOREncodable? = nil,
        clientDataHash: Data,
        flags: AuthenticatorDataFlags? = nil)
    throws -> ASPasskeyRegistrationCredential
    {
        let authData = try createAuthenticatorData(
            rpId: rpId,
            flags: flags,
            credentialId: credentialId,
            privateKey: privateKey,
            authenticatorExtensions: authenticatorExtensions)

        let attestation = Attestation(authData: authData)

        return .init(
            relyingParty: rpId,
            clientDataHash: clientDataHash,
            credentialID: credentialId,
            attestationObject: try attestation.raw,
            extensionOutput: nil)
    }


    let attestation: [String: Any?]

    var raw: Data {
        get throws {
            Data(try CBOR.encodeMap(attestation))
        }
    }


    init(authData: Data) {
        attestation = [
            "authData": authData,
            "fmt": "none",
            "attStmt": [:]
        ]
    }


    private class func createAuthenticatorData(
        rpId: String,
        flags: AuthenticatorDataFlags? = nil,
        credentialId: Data,
        privateKey: SecKey,
        aaguid: UUID = Attestation.aaguid,
        authenticatorExtensions: CBOREncodable? = nil)
    throws -> Data
    {
        guard let publicKey = privateKey.publicKey else {
            throw Errors.couldNotFindPublicKey
        }

        let keyData = try publicKey.keyData
        let publicKeyCose = try Self.rawEcKeyToCose(keyData)
        let attestedCredential = makeAttestedCredentialData(aaguid, publicKeyCose, credentialId)

        var extensionsCborBytes: [UInt8]? = nil
        if let authenticatorExtensions {
            extensionsCborBytes = CBOR.encode(authenticatorExtensions)
        }

        let authData = try makeAuthData(
            rpId: rpId,
            flags: flags,
            attestedCredentialData: attestedCredential,
            extensionsCborBytes: extensionsCborBytes)

        return authData
    }

    private class func makeAuthData(
        rpId: String,
        flags: AuthenticatorDataFlags? = nil,
        signatureCount: Int = 0,
        attestedCredentialData: Data? = nil,
        extensionsCborBytes: [UInt8]? = nil)
    throws -> Data
    {
        guard let rpId = rpId.data(using: .utf8) else {
            throw Errors.couldNotEncodeRpId
        }

        var data = Data()

        data.append(contentsOf: Self.sha256(rpId))

        var flags = try flags ?? .init()
        flags.UP = true
        flags.AT = attestedCredentialData != nil
        flags.ED = extensionsCborBytes != nil

        data.append(contentsOf: [flags.value])

        var signatureCount = UInt32(signatureCount).bigEndian
        let signatureCountData = Data(bytes: &signatureCount, count: MemoryLayout<UInt32>.size)
        data.append(signatureCountData)

        if let attestedCredentialData {
            data.append(attestedCredentialData)
        }

        if let extensionsCborBytes {
            data.append(contentsOf: extensionsCborBytes)
        }

        return data
    }

    private class func makeAttestedCredentialData(_ aaguid: UUID = Attestation.aaguid, _ publicKeyCose: Data, _ credentialId: Data)
    -> Data
    {
        var data = Data()
        data.append(contentsOf: aaguid.bytes)

        var credentialIdCount = UInt16(credentialId.count).bigEndian
        let credentialIdCountData = Data(bytes: &credentialIdCount, count: MemoryLayout<UInt16>.size)
        data.append(credentialIdCountData)

        data.append(credentialId)

        data.append(publicKeyCose)

        return data
    }

    private class func sha256(_ input: Data) -> Data {
        Data(SHA256.hash(data: input))
    }

    private class func rawEcKeyToCose(_ key: Data) throws -> Data {
        let len = key.count
        let lenSub1 = key.count - 1

        if !(len == 64
              || len == 96
              || len == 132
             || (key[0] == 0x04 && (lenSub1 == 64 || lenSub1 == 96 || lenSub1 == 132)))
        {
            throw Errors.keyInvalidLength(length: len, firstByte: key[0])
        }

        let start = (len == 64 || len == 96 || len == 132) ? 0 : 1
        let coordinateLength = (len - start) / 2

        var coseKey = [Int: Any]()
        coseKey[1] = 2 // Key type: EC


        let coseAlg: CoseAlgorithmIdentifier
        let coseCrv: Int

        switch (len - start) {
        case 64:
          coseAlg = .ES256
          coseCrv = 1

        case 96:
          coseAlg = .ES384
          coseCrv = 2

        case 132:
          coseAlg = .ES512
          coseCrv = 3

        default:
            throw Errors.unknownCoseAlgo
        }

        coseKey[3] = coseAlg.rawValue
        coseKey[-1] = coseCrv

        coseKey[-2] = key[start ..< start + coordinateLength] // x
        coseKey[-3] = key[start + coordinateLength ..< start + 2 * coordinateLength] // y

        return Data(try CBOR.encodeMap(coseKey))
    }
}

enum CoseAlgorithmIdentifier: Int32 {

    /**
     The signature scheme Ed25519 as defined in <https://www.rfc-editor.org/rfc/rfc8032>.

     Note: This COSE identifier does not in general identify the full Ed25519 parameter suite,
     but is specialized to that meaning within the WebAuthn API.

     - see  <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     - see <https://www.rfc-editor.org/rfc/rfc8032>
     - see <https://www.w3.org/TR/2021/REC-webauthn-2-20210408/#sctn-alg-identifier>
     */
    case EdDSA = -8

    /**
     ECDSA with SHA-256 on the NIST P-256 curve.

     Note: This COSE identifier does not in general restrict the curve to P-256, but is
     specialized to that meaning within the WebAuthn API.

     - see <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     - see <https://www.w3.org/TR/2021/REC-webauthn-2-20210408/#sctn-alg-identifier>
     */
    case ES256 = -7

    /**
     ECDSA with SHA-384 on the NIST P-384 curve.

     Note: This COSE identifier does not in general restrict the curve to P-384, but is
     specialized to that meaning within the WebAuthn API.

     - see <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     - see <https://www.w3.org/TR/2021/REC-webauthn-2-20210408/#sctn-alg-identifier>
     */
    case ES384 = -35

    /**
     ECDSA with SHA-512 on the NIST P-521 curve.

     <p>Note: This COSE identifier does not in general restrict the curve to P-521, but is
     specialized to that meaning within the WebAuthn API.

     - see <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     - see <https://www.w3.org/TR/2021/REC-webauthn-2-20210408/#sctn-alg-identifier>
     */
    case ES512 = -36

    /**
     RSASSA-PKCS1-v1_5 using SHA-256.

     - see <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     */
    case RS256 = -257

    /**
     RSASSA-PKCS1-v1_5 using SHA-384.

     - see <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     */
    case RS384 = -258

    /**
     RSASSA-PKCS1-v1_5 using SHA-512.

     - see <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     */
    case RS512 = -259

    /**
     RSASSA-PKCS1-v1_5 using SHA-1.

     - see <https://www.iana.org/assignments/cose/cose.xhtml#algorithms>
     */
    case RS1 = -65535
}
