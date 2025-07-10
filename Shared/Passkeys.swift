//
//  Passkeys.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 30.05.25.
//

import Foundation
import OSLog

class Passkeys {

    static let shared = Passkeys()


    private static let file = URL.groupFolder?.appendingPathComponent("passkeys.plist")


    private var passkeys: [String: [Passkey]]

    private let log: Logger


    private init() {
        log = Logger(
            subsystem: Bundle(for: Self.self).bundleIdentifier ?? String(describing: Self.self),
            category: String(describing: Self.self))

        do {
            guard let url = Self.file else {
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
            }

            let data = try Data(contentsOf: url, options: .alwaysMapped)

            passkeys = try PropertyListDecoder().decode([String: [Passkey]].self, from: data)
        }
        catch {
            log.error("\(error)")

            passkeys = [:]
        }
    }


    func getPasskeys(for relyingPartyId: String) -> [Passkey] {
        passkeys[relyingPartyId] ?? []
    }

    func storePasskey(relyingPartyId: String, label: String, keyId: Data, userHandle: Data, userVerified: Bool) throws {
        if passkeys[relyingPartyId] == nil {
            passkeys[relyingPartyId] = []
        }

        passkeys[relyingPartyId]?.append(Passkey(label: label, keyId: keyId, userHandle: userHandle, userVerified: userVerified))

        guard let url = Self.file else {
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
        }

        let data = try PropertyListEncoder().encode(passkeys)

        try data.write(to: url, options: .atomic)
    }
}

struct Passkey: Codable {

    let label: String

    let keyId: Data

    let userHandle: Data

    let userVerified: Bool

    var keyIdString: String? {
        UUID.from(data: keyId)?.uuidString
    }

    var privateKey: SecKey? {
        try? SecureEnclave.loadPrivateKey(tag: keyId)
    }
}
