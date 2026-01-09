//
//  JsonModels.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 11.04.25.
//

import Foundation
import YubiKit

struct CreateRequestWrapper: Decodable {

    let type: String
    let request: CreateRequest
}

struct CreateRequest: Decodable {

    enum CodingKeys: String, CodingKey {
        case rp
        case user
        case challenge
        case pubKeyCredParams
        case excludeCredentials
        case authenticatorSelection
        case attestation
        case extensions
    }

    let rp: RelyingParty
    let user: User
    let challenge: String
    let pubKeyCredParams: [PubKeyCredParams]
    let excludeCredentials: [Credentials]?
    let authenticatorSelection: AuthenticatorSelection?
    let attestation: String?
    let extensions: [String: Any]?

    var clientData: WebAuthnClientData? {
        WebAuthnClientData(type: .create, challenge: challenge, origin: "https://\(rp.id)")
    }

    var options: CTAP2.MakeCredential.Parameters.Options? {
        if authenticatorSelection?.residentKey == "preferred"
            || authenticatorSelection?.residentKey == "required"
            || authenticatorSelection?.requireResidentKey == true
        {
            return CTAP2.MakeCredential.Parameters.Options(rk: true)
        }

        return nil
    }

    var extensionsInput: CTAP2.Extension.MakeCredential.Input? {
        guard let extensions else {
            return nil
        }

        var encoded = [CTAP2.Extension.Identifier: CBOR.Value]()

        for (key, value) in extensions {
            encoded[CTAP2.Extension.Identifier(key)] = Self.cborValue(from: value)
        }

        guard !encoded.isEmpty else {
            return nil
        }

        return CTAP2.Extension.MakeCredential.Input(encoded: encoded)
    }


    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        rp = try container.decode(RelyingParty.self, forKey: .rp)
        user = try container.decode(User.self, forKey: .user)
        challenge = try container.decode(String.self, forKey: .challenge)
        pubKeyCredParams = try container.decode([PubKeyCredParams].self, forKey: .pubKeyCredParams)
        excludeCredentials = try container.decodeIfPresent([Credentials].self, forKey: .excludeCredentials)
        authenticatorSelection = try container.decodeIfPresent(AuthenticatorSelection.self, forKey: .authenticatorSelection)
        attestation = try container.decodeIfPresent(String.self, forKey: .attestation)
        extensions = try container.decodeIfPresent([String: Any].self, forKey: .extensions)
    }


    static func cborValue(from any: Any?) -> CBOR.Value? {
        switch any {
        case let value as Bool:
            return CBOR.Value(value)

        case let value as Int:
            return CBOR.Value(Int64(value))

        case let value as Int8:
            return CBOR.Value(Int64(value))

        case let value as Int16:
            return CBOR.Value(Int64(value))

        case let value as Int32:
            return CBOR.Value(Int64(value))

        case let value as Int64:
            return CBOR.Value(Int64(value))

        case let value as UInt:
            return CBOR.Value(UInt64(value))

        case let value as UInt8:
            return CBOR.Value(UInt64(value))

        case let value as UInt16:
            return CBOR.Value(UInt64(value))

        case let value as UInt32:
            return CBOR.Value(UInt64(value))

        case let value as UInt64:
            return CBOR.Value(UInt64(value))

        case let value as Double:
            return CBOR.Value(UInt64(value))

        case let value as Float:
            return CBOR.Value(UInt64(value))

        case let value as Float16:
            return CBOR.Value(UInt64(value))

        case let value as Float32:
            return CBOR.Value(UInt64(value))

        case let value as Float64:
            return CBOR.Value(UInt64(value))

        case let value as String:
            return CBOR.Value(value)

        case let value as Data:
            return CBOR.Value(value)

        case let value as [Any]:
            return CBOR.Value(value.compactMap({ cborValue(from: $0) }))

        case let value as [String: Any]:
            var cborMap = [CBOR.Value: CBOR.Value]()

            for (key, value) in value {
                cborMap[CBOR.Value(key)] = cborValue(from: value)
            }

            return CBOR.Value(cborMap)

        case Optional<Any>.none:
            return .null

        case is NSNull:
            return .null

        default:
            return nil
        }
    }
}


struct RelyingParty: Codable {

    let id: String
    let name: String?

    var entity: WebAuthn.PublicKeyCredential.RPEntity {
        WebAuthn.PublicKeyCredential.RPEntity(id: id, name: name)
    }
}

struct User: Codable {

    let id: String
    let name: String?
    let displayName: String?

    var entity: WebAuthn.PublicKeyCredential.UserEntity? {
        guard let data = id.webSafeBase64DecodedData() else {
            return nil
        }

        return WebAuthn.PublicKeyCredential.UserEntity(id: data, name: name, displayName: displayName)
    }
}

struct PubKeyCredParams: Codable {

    let type: String?
    let alg: Int

    var algorithm: COSE.Algorithm {
        COSE.Algorithm(rawValue: alg)
    }
}

struct AuthenticatorSelection: Codable {

    let requireResidentKey: Bool?
    let residentKey: String?
    let userVerification: String?
}

struct GetRequestWrapper: Decodable {

    let type: String
    let request: GetRequest
}

struct GetRequest: Decodable {

    enum CodingKeys: String, CodingKey {
        case rpId
        case challenge
        case allowCredentials
        case userVerification
        case extensions
    }

    let rpId: String
    let challenge: String
    let allowCredentials: [Credentials]?
    let userVerification: String?
    let extensions: [String: Any]?

    var clientData: WebAuthnClientData? {
        WebAuthnClientData(type: .get, challenge: challenge, origin: "https://\(rpId)")
    }

    var extensionsInput: CTAP2.Extension.GetAssertion.Input? {
        guard let extensions else {
            return nil
        }

        var encoded = [CTAP2.Extension.Identifier: CBOR.Value]()

        for (key, value) in extensions {
            encoded[CTAP2.Extension.Identifier(key)] = CreateRequest.cborValue(from: value)
        }

        guard !encoded.isEmpty else {
            return nil
        }

        return CTAP2.Extension.GetAssertion.Input(encoded: encoded)
    }


    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        rpId = try container.decode(String.self, forKey: .rpId)
        challenge = try container.decode(String.self, forKey: .challenge)
        allowCredentials = try container.decodeIfPresent([Credentials].self, forKey: .allowCredentials)
        userVerification = try container.decodeIfPresent(String.self, forKey: .userVerification)
        extensions = try container.decodeIfPresent([String: Any].self, forKey: .extensions)
    }
}

struct Credentials: Codable {

    enum CodingKeys: CodingKey {
        case type
        case id
        case transports
        case response
        case rawId
        case clientExtensionResults
        case authenticatorAttachment
    }

    let type: String
    let id: String?
    let transports: [String]?

    let response: Response?
    let rawId: String?
    let clientExtensionResults: Extensions?
    let authenticatorAttachment: String?

    var descriptor: WebAuthn.PublicKeyCredential.Descriptor? {
        guard let data = id?.webSafeBase64DecodedData() else {
            return nil
        }

        return WebAuthn.PublicKeyCredential.Descriptor(type: type, id: data, transports: transports)
    }

    init(_ clientData: WebAuthnClientData, _ response: CTAP2.GetAssertion.Response) {
        type = "public-key"
        id = response.credential?.id.webSafeBase64EncodedString()
        transports = nil

        self.response = Response(clientData, response)
        rawId = id
        clientExtensionResults = Extensions(response.authenticatorData.extensions)
        authenticatorAttachment = "cross-platform"
    }

    init(_ clientData: WebAuthnClientData, _ response: CTAP2.MakeCredential.Response) {
        type = "public-key"
        id = response.authenticatorData.attestedCredentialData?.credentialId.webSafeBase64EncodedString()
        transports = nil

        self.response = Response(clientData, response)
        rawId = id
        clientExtensionResults = Extensions(response.authenticatorData.extensions)
        authenticatorAttachment = "cross-platform"

    }
}

struct Response: Codable {

    enum CodingKeys: String, CodingKey {
        case clientDataJson = "clientDataJSON"
        case authenticatorData
        case signature
        case userHandle
        case transports
        case attestationObject
        case publicKeyAlgorithm
    }

    let clientDataJson: String?
    let authenticatorData: String

    // GET
    let signature: String?
    let userHandle: String?

    // MAKE
    let transports: [String]?
    let attestationObject: String?
    let publicKeyAlgorithm: Int?

    init(_ clientData: WebAuthnClientData, _ response: CTAP2.GetAssertion.Response) {
        clientDataJson = try? clientData.jsonData.webSafeBase64EncodedString()

        authenticatorData = response.authenticatorData.rawData.webSafeBase64EncodedString()
        signature = response.signature.webSafeBase64EncodedString()
        userHandle = response.user?.id.webSafeBase64EncodedString()

        transports = nil
        attestationObject = nil
        publicKeyAlgorithm = nil
    }

    init(_ clientData: WebAuthnClientData, _ response: CTAP2.MakeCredential.Response) {
        clientDataJson = try? clientData.jsonData.webSafeBase64EncodedString()

        authenticatorData = response.authenticatorData.rawData.webSafeBase64EncodedString()
        signature = nil
        userHandle = nil

        transports = ["nfc", "usb"]

        switch response.attestationStatement {
        case .packed(let packed):
            attestationObject = packed.rawData.webSafeBase64EncodedString()

        case .fidoU2F(let fidoU2f):
            attestationObject = fidoU2f.rawData.webSafeBase64EncodedString()

        case .none:
            attestationObject = nil

        case .apple(let apple):
            attestationObject = apple.rawData.webSafeBase64EncodedString()

        case .unknown(format: _):
            attestationObject = nil
        }

        switch response.authenticatorData.attestedCredentialData!.credentialPublicKey {
        case .ec2(let alg, kid: _, crv: _, x: _, y: _):
            publicKeyAlgorithm = alg.rawValue

        case .okp(let alg, kid: _, crv: _, x: _):
            publicKeyAlgorithm = alg.rawValue

        case .rsa(let alg, kid: _, n: _, e: _):
            publicKeyAlgorithm = alg.rawValue

        case .other(_):
            publicKeyAlgorithm = nil
        }
    }
}

struct ResponseWrapper: Codable {

    enum CodingKeys: String, CodingKey {
        case success = "0"
        case credentials = "1"
        case method = "2"
    }

    let success: String
    let credentials: Credentials
    let method: String

    init(_ credentials: Credentials, _ method: String) {
        success = "success"
        self.credentials = credentials
        self.method = method
    }
}

struct Extensions: Codable {

    let prf: Prf?

    init?(_ data: [WebAuthn.Extension.Identifier: CBOR.Value]?) {
        guard let data = data,
              let value = data[.other("prf")],
              case .map(let map) = value
        else {
            return nil
        }

        prf = Prf(map)
    }
}

struct Prf: Codable {

    let eval: PrfKeys?
    let results: PrfKeys?
    let enabled: Bool?

    init?(_ data: [CBOR.Value: CBOR.Value]?) {
        guard let data = data else {
            return nil
        }

        if case .map(let map) = data[.textString("eval")] {
            eval = PrfKeys(map)
        }
        else {
            eval = nil
        }

        if case .map(let map) = data[.textString("results")] {
            results = PrfKeys(map)
        }
        else {
            results = nil
        }

        if case .boolean(let bool) = data[.textString("enabled")] {
            enabled = bool
        }
        else {
            enabled = nil
        }
    }
}

struct PrfKeys: Codable {

    let first: String?

    init?(_ data: [CBOR.Value: CBOR.Value]?) {
        guard let data = data else {
            return nil
        }

        if case .textString(let value) = data[.textString("first")] {
            first = value
        }
        else {
            first = nil
        }
    }
}

struct JSONCodingKeys: CodingKey {

    let stringValue: String

    private(set) var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init(intValue: Int) {
        self.init(stringValue: String(intValue))
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer {

    func decode(_ type: Dictionary<String, Any>.Type, forKey key: K) throws -> Dictionary<String, Any> {
        let container = try nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)

        return try container.decode(type)
    }

    func decodeIfPresent(_ type: Dictionary<String, Any>.Type, forKey key: K) throws -> Dictionary<String, Any>? {
        guard contains(key),
              try decodeNil(forKey: key) == false
        else {
            return nil
        }

        return try decode(type, forKey: key)
    }

    func decode(_ type: Array<Any>.Type, forKey key: K) throws -> Array<Any> {
        var container = try nestedUnkeyedContainer(forKey: key)

        return try container.decode(type)
    }

    func decodeIfPresent(_ type: Array<Any>.Type, forKey key: K) throws -> Array<Any>? {
        guard contains(key),
              try decodeNil(forKey: key) == false
        else {
            return nil
        }

        return try decode(type, forKey: key)
    }

    func decode(_ type: Dictionary<String, Any>.Type) throws -> Dictionary<String, Any> {
        var dictionary = Dictionary<String, Any>()

        for key in allKeys {
            if let boolValue = try? decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            }
            else if let stringValue = try? decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            }
            else if let intValue = try? decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            }
            else if let doubleValue = try? decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            }
            else if let nestedDictionary = try? decode(Dictionary<String, Any>.self, forKey: key) {
                dictionary[key.stringValue] = nestedDictionary
            }
            else if let nestedArray = try? decode(Array<Any>.self, forKey: key) {
                dictionary[key.stringValue] = nestedArray
            }
        }

        return dictionary
    }
}

extension UnkeyedDecodingContainer {

    mutating func decode(_ type: Array<Any>.Type) throws -> Array<Any> {
        var array = [Any]()

        while isAtEnd == false {
            // See if the current value in the JSON array is `null` first and prevent infite recursion with nested arrays.
            if try decodeNil() {
                continue
            }
            else if let value = try? decode(Bool.self) {
                array.append(value)
            }
            else if let value = try? decode(Double.self) {
                array.append(value)
            }
            else if let value = try? decode(String.self) {
                array.append(value)
            }
            else if let nestedDictionary = try? decode(Dictionary<String, Any>.self) {
                array.append(nestedDictionary)
            }
            else if let nestedArray = try? decode(Array<Any>.self) {
                array.append(nestedArray)
            }
        }

        return array
    }

    mutating func decode(_ type: Dictionary<String, Any>.Type) throws -> Dictionary<String, Any> {
        let nestedContainer = try nestedContainer(keyedBy: JSONCodingKeys.self)

        return try nestedContainer.decode(type)
    }
}

