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

    enum Errors: LocalizedError {

        case couldNotEncodeRpId
        case couldNotFindPublicKey
        case keyInvalidLength(length: Int, firstByte: UInt8)
        case unknownCoseAlgo

        var localizedDescription: String {
            switch self {
            case .couldNotEncodeRpId:
                return "Could not encode Relying Party ID!"

            case .couldNotFindPublicKey:
                return "Could not find public key!"

            case .keyInvalidLength(let length, let firstByte):
                return "Raw key must be 64, 96 or 132 bytes long, or start with 0x04 and be 65, 97 or 133 bytes long; was \(length) bytes starting with \(firstByte)"

            case .unknownCoseAlgo:
                return "Failed to determine COSE EC algorithm. This should not be possible, please file a bug report."
            }
        }
    }

    /**
     Autheticator Attestation GUID
     */
    static let aaguid = UUID(uuidString: "0a073192-1e1e-4d90-ade2-0fc6d19ceb03")!

    static let shared = Attestation()

    func createRegistrationCredential(
        privateKey: SecKey,
        rpId: String,
        authenticatorExtensions: CBOREncodable? = nil,
        challenge: Data,
        flags: AuthenticatorDataFlags? = nil)
    throws -> ASPasskeyRegistrationCredential
    {
        let result = try createAuthenticatorData(
            rpId: rpId,
            flags: flags,
            privateKey: privateKey,
            authenticatorExtensions: authenticatorExtensions)

        let clientData = try createClientData(challenge: challenge, rpId: rpId)

        let ao = try AttestationMakerNone().makeAttestationObject(result.authData, clientData)

        return ASPasskeyRegistrationCredential(
            relyingParty: rpId,
            clientDataHash: Self.sha256(clientData),
            credentialID: result.credentialId,
            attestationObject: Data(ao),
            extensionOutput: nil)
    }

    private func createAuthenticatorData(
        rpId: String,
        flags: AuthenticatorDataFlags? = nil,
        privateKey: SecKey,
        aaguid: UUID = Attestation.aaguid,
        authenticatorExtensions: CBOREncodable? = nil)
    throws -> (authData: Data, credentialId: Data)
    {
        guard let publicKey = SecureEnclave.getPublicKey(from: privateKey) else {
            throw Errors.couldNotFindPublicKey
        }

        let keyData = try SecureEnclave.getKeyData(from: publicKey)
        let publicKeyCose = try Self.rawEcKeyToCose(keyData)
        let result = makeAttestedCredentialData(aaguid, publicKeyCose)

        var extensionsCborBytes: [UInt8]? = nil
        if let authenticatorExtensions {
            extensionsCborBytes = CBOR.encode(authenticatorExtensions)
        }

        let authData = try makeAuthData(
            rpId: rpId,
            flags: flags,
            attestedCredentialData: result.attestedCredential,
            extensionsCborBytes: extensionsCborBytes)

        return (authData, result.credentialId)
    }

    private func makeAuthData(
        rpId: String,
        flags: AuthenticatorDataFlags? = nil,
        signatureCount: Int = 1337,
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

    private func makeAttestedCredentialData(_ aaguid: UUID = Attestation.aaguid, _ publicKeyCose: Data)
    -> (attestedCredential: Data, credentialId: Data)
    {
        var data = Data()
        data.append(contentsOf: aaguid.bytes)

        let credentialId = Self.sha256(publicKeyCose)

        var credentialIdCount = UInt16(credentialId.count).bigEndian
        let credentialIdCountData = Data(bytes: &credentialIdCount, count: MemoryLayout<UInt16>.size)
        data.append(credentialIdCountData)

        data.append(credentialId)

        data.append(publicKeyCose)

        return (data, credentialId)
    }

    private func createClientData(
        challenge: Data,
        rpId: String,
        tokenBindingStatus: String = "supported",
        tokenBindingId: String? = nil)
    throws -> Data
    {
        return try JSONEncoder().encode(ClientData(
            challenge: challenge.webSafeBase64EncodedString(),
            origin: "https://\(rpId)",
            type: "webauthn.create",
            tokenBinding: .init(status: tokenBindingStatus, id: tokenBindingId)))
    }


    private class func sha256(_ input: Data) -> Data {
        var digest = SHA256()
        digest.update(data: input)

        return Data(digest.finalize())
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

struct AuthenticatorDataFlags {

    enum Errors: LocalizedError {

        case invalidCombination(UInt8)

        var localizedDescription: String {
            switch self {
            case .invalidCombination(let value):
                return "Flag combination BE=0, BS=1 is invalid: \(value)"
            }
        }
    }

    private class Bitmasks {
        static let UP: UInt8 = 0x01
        static let UV: UInt8 = 0x04
        static let BE: UInt8 = 0x08
        static let BS: UInt8 = 0x10
        static let AT: UInt8 = 0x40
        static let ED : UInt8 = 0x80

        // Reserved bits
        static let RFU1 : UInt8 = 0x02
        static let RFU2 : UInt8 = 0x20
    }

    private(set) var value: UInt8

    /**
     User Present
     */
    var UP: Bool {
        get {
            (value & Bitmasks.UP) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.UP) : (value & ~Bitmasks.UP)
        }
    }

    /**
     User Verified
     */
    var UV: Bool {
        get {
            (value & Bitmasks.UV) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.UV) : (value & ~Bitmasks.UV)
        }
    }

    /**
     Backup eligible: the credential can and is allowed to be backed up.

     NOTE that this is only a hint and not a guarantee, unless backed by a trusted authenticator attestation.

     <https://w3c.github.io/webauthn/#authdata-flags-be>

     @DeprecationSummary {
        EXPERIMENTAL: This feature is from a not yet mature standard; it could change as the standard matures.
     }
     */
    var BE: Bool {
        get {
            (value & Bitmasks.BE) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.BE) : (value & ~Bitmasks.BE)
        }
    }

    /**
     Backup status: the credential is currently backed up.

     NOTE that this is only a hint and not a guarantee, unless backed by a trusted authenticator attestation.

     <https://w3c.github.io/webauthn/#authdata-flags-bs>

     @DeprecationSummary {
         EXPERIMENTAL: This feature is from a not yet mature standard; it could change as the standard matures.
     }
     */
    var BS: Bool {
        get {
            (value & Bitmasks.BS) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.BS) : (value & ~Bitmasks.BS)
        }
    }

    /**
     Attested credential data present.
     */
    var AT: Bool {
        get {
            (value & Bitmasks.AT) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.AT) : (value & ~Bitmasks.AT)
        }
    }

    /**
     Extension data present.
     */
    var ED: Bool {
        get {
            (value & Bitmasks.ED) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.ED) : (value & ~Bitmasks.ED)
        }
    }

    init(value: UInt8 = 0x00) throws {
        self.value = value

        if BS && !BE {
            throw Errors.invalidCombination(value)
        }
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

struct ClientData: Codable {

    let challenge: String
    let origin: String
    let type: String
    let tokenBinding: TokenBinding
}

struct TokenBinding: Codable {

    let status: String
    let id: String?
}

protocol AttestationMaker {

    var format: String { get }

    var certChain: [(x509Certificate: Data, privateKey: SecKey)] { get }

    func makeAttestationStatement(_ authData: Data, _ clientDataJson: Data) -> [String: Any?]
}

extension AttestationMaker {

    static func none() -> AttestationMakerNone {
        return AttestationMakerNone()
    }

    func makeAttestationObject(_ authData: Data, _ clientDataJson: Data) throws -> [UInt8] {
        let ao: [String: Any?] = [
            "authData": authData,
            "fmt": format,
            "attStmt": makeAttestationStatement(authData, clientDataJson)
        ]

        return try CBOR.encodeMap(ao)
    }
}

class AttestationMakerNone: AttestationMaker {

    var format = "none"

    var certChain = [(x509Certificate: Data, privateKey: SecKey)]()

    func makeAttestationStatement(_ authData: Data, _ clientDataJson: Data) -> [String: Any?] {
        return [:]
    }
}
