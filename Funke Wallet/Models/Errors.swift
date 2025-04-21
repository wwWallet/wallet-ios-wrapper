//
//  Errors.swift
//  Funke Wallet
//
//  Created by Benjamin Erhart on 11.04.25.
//

import Foundation

enum Errors: LocalizedError {

    case cannotDecodeMessage
    case cannotCreateClientDataHash
    case cannotCreateUserEntity
    case error0x19
    case invalidUuid

    var localizedDescription: String {
        switch self {
        case .cannotDecodeMessage:
            return NSLocalizedString("Cannot decode message.", comment: "")

        case .cannotCreateClientDataHash:
            return NSLocalizedString("Cannot create clientDataHash", comment: "")

        case .cannotCreateUserEntity:
            return NSLocalizedString("Cannot create user entity", comment: "")

        case .error0x19:
            return "0x19"

        case .invalidUuid:
            return NSLocalizedString("Not a valid UUID string.", comment: "")
        }
    }
}
