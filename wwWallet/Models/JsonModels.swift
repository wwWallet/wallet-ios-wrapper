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

    var clientData: YKFWebAuthnClientData? {
        guard let data = challenge.webSafeBase64DecodedData() else {
            return nil
        }

        return YKFWebAuthnClientData(type: .create, challenge: data, origin: "https://\(rp.id)")
    }

    var options: [String: Bool]? {
        if authenticatorSelection?.residentKey == "preferred"
            || authenticatorSelection?.residentKey == "required"
            || authenticatorSelection?.requireResidentKey == true
        {
            return ["rk": true]
        }

        return nil
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
}

struct RelyingParty: Codable {

    let id: String
    let name: String?

    var entity: YKFFIDO2PublicKeyCredentialRpEntity {
        let entity = YKFFIDO2PublicKeyCredentialRpEntity()
        entity.rpId = id
        entity.rpName = name

        return entity
    }
}

struct User: Codable {

    let id: String
    let name: String?
    let displayName: String?

    var entity: YKFFIDO2PublicKeyCredentialUserEntity? {
        guard let data = id.webSafeBase64DecodedData() else {
            return nil
        }

        let entity = YKFFIDO2PublicKeyCredentialUserEntity()
        entity.userId = data
        entity.userName = name
        entity.userDisplayName = displayName

        return entity
    }
}

struct PubKeyCredParams: Codable {

    let type: String?
    let alg: Int

    var param: YKFFIDO2PublicKeyCredentialParam {
        let param = YKFFIDO2PublicKeyCredentialParam()
        param.alg = alg

        return param
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

    var clientData: YKFWebAuthnClientData? {
        guard let data = challenge.webSafeBase64DecodedData() else {
            return nil
        }

        return YKFWebAuthnClientData(type: .get, challenge: data, origin: "https://\(rpId)")
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

    var descriptor: YKFFIDO2PublicKeyCredentialDescriptor? {
        guard let data = id?.webSafeBase64DecodedData() else {
            return nil
        }

        let d = YKFFIDO2PublicKeyCredentialDescriptor()
        d.credentialId = data
        d.credentialType = .init()
        d.credentialType.name = type

        return d
    }

    init(_ clientData: YKFWebAuthnClientData, _ response: YKFFIDO2GetAssertionResponse) {
        type = "public-key"
        id = response.credential?.credentialId.webSafeBase64EncodedString()
        transports = nil

        self.response = Response(clientData, response)
        rawId = id
        clientExtensionResults = Extensions(response.extensionsOutput)
        authenticatorAttachment = "cross-platform"
    }

    init(_ clientData: YKFWebAuthnClientData, _ response: YKFFIDO2MakeCredentialResponse, _ extensionResult: [AnyHashable: Any]) {
        type = "public-key"
        id = response.authenticatorData?.credentialId?.webSafeBase64EncodedString()
        transports = nil

        self.response = Response(clientData, response)
        rawId = id
        clientExtensionResults = Extensions(extensionResult)
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

    init(_ clientData: YKFWebAuthnClientData, _ response: YKFFIDO2GetAssertionResponse) {
        clientDataJson = clientData.jsonData?.webSafeBase64EncodedString()

        authenticatorData = response.authData.webSafeBase64EncodedString()
        signature = response.signature.webSafeBase64EncodedString()
        userHandle = response.user?.userId.webSafeBase64EncodedString()

        transports = nil
        attestationObject = nil
        publicKeyAlgorithm = nil
    }

    init(_ clientData: YKFWebAuthnClientData, _ response: YKFFIDO2MakeCredentialResponse) {
        clientDataJson = clientData.jsonData?.webSafeBase64EncodedString()

        authenticatorData = response.authData.webSafeBase64EncodedString()
        signature = nil
        userHandle = nil

        transports = ["nfc", "usb"]
        attestationObject = response.webauthnAttestationObject.webSafeBase64EncodedString()

        if let publicKey = response.authenticatorData?.coseEncodedCredentialPublicKey,
           let cborMap = YKFCBORDecoder.decodeDataObject(from: publicKey) as? YKFCBORMap,
           let map = YKFCBORDecoder.convertCBORObject(toFoundationType: cborMap) as? [Int: Any]
        {
            publicKeyAlgorithm = map[3] as? Int
        }
        else {
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

    init?(_ data: [AnyHashable: Any]?) {
        guard let data = data else {
            return nil
        }

        prf = Prf(data["prf"] as? [AnyHashable: Any])
    }
}

struct Prf: Codable {

    let eval: PrfKeys?
    let results: PrfKeys?
    let enabled: Bool?

    init?(_ data: [AnyHashable: Any]?) {
        guard let data = data else {
            return nil
        }

        eval = PrfKeys(data["eval"] as? [AnyHashable: Any])
        results = PrfKeys(data["results"] as? [AnyHashable: Any])
        enabled = data["enabled"] as? Bool
    }
}

struct PrfKeys: Codable {

    let first: String?

    init?(_ data: [AnyHashable: Any]?) {
        guard let data = data else {
            return nil
        }

        first = data["first"] as? String
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

