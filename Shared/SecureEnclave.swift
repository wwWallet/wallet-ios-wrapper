//
//  SecureEnclave.swift
//  AutoFillExtension
//
//  Created by Benjamin Erhart on 29.05.25.
//

import Foundation

class SecureEnclave {

    class func createPrivateKey(tag: UUID, userVerification: Bool) throws -> SecKey {
        var error: Unmanaged<CFError>?

        var flags: SecAccessControlCreateFlags = [.privateKeyUsage]

        if userVerification {
            flags.insert(.and)
            flags.insert(.userPresence)
        }

        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            &error)
        else {
            throw error!.takeRetainedValue()
        }

        let parameters: NSDictionary = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tag.data,
                kSecAttrAccessControl: accessControl]
        ]

        guard let privateKey = SecKeyCreateRandomKey(parameters, &error)
        else {
            throw error!.takeRetainedValue()
        }

        return privateKey
    }

    class func loadPrivateKeys() throws -> [SecKey] {
        let query: NSDictionary = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnRef: true]

        var result: CFTypeRef?

        do {
            try throwIfError(SecItemCopyMatching(query, &result))
        }
        catch {
            if (error as NSError).code == errSecItemNotFound {
                return []
            }

            throw error
        }

        return (result as! NSArray) as! [SecKey]
    }

    class func loadPrivateKey(tag: Data) throws -> SecKey {
        let query: NSDictionary = [
            kSecAttrApplicationTag: tag,
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef: true]

        var result: CFTypeRef?

        try throwIfError(SecItemCopyMatching(query, &result))

        return (result as! SecKey)
    }

    class func removePrivateKey(tag: Data) throws {
        let query: NSDictionary = [
            kSecAttrApplicationTag: tag,
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom]

        try throwIfError(SecItemDelete(query))
    }

    class func removeAllPrivateKeys() throws {
        let query: NSDictionary = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom]

        try throwIfError(SecItemDelete(query))
    }

    class func getPublicKey(from privateKey: SecKey) -> SecKey? {
        return SecKeyCopyPublicKey(privateKey)
    }

    class func getKeyData(from key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?

        guard let data = SecKeyCopyExternalRepresentation(key, &error)
        else {
            throw error!.takeRetainedValue()
        }

        return data as Data
    }

    class func sign(_ data: Data, with privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?

        guard let signature = SecKeyCreateSignature(privateKey, .ecdsaSignatureMessageX962SHA256, data as CFData, &error)
        else {
            throw error!.takeRetainedValue()
        }

        return signature as Data
    }

    private class func throwIfError(_ status: OSStatus) throws {
        if status == errSecSuccess {
            return
        }
        
        let error = SecCopyErrorMessageString(status, nil)
        
        throw NSError(domain: String(describing: self), code: Int(status), userInfo: [NSLocalizedDescriptionKey: error ?? "Unknown error"])
    }
}

extension SecKey {

    private var attributes: NSDictionary? {
        SecKeyCopyAttributes(self) as NSDictionary?
    }

    var tag: Data? {
        let attributes = attributes

        return attributes?[kSecAttrApplicationTag] as? Data
    }

    var tagId: String? {
        UUID.from(data: tag ?? Data())?.uuidString
    }

    var publicKey: SecKey? {
        SecureEnclave.getPublicKey(from: self)
    }

    var keyData: Data {
        get throws {
            try SecureEnclave.getKeyData(from: self)
        }
    }


    func sign(_ data: Data) throws -> Data {
        try SecureEnclave.sign(data, with: self)
    }
}
