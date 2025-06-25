//
//  Errors.swift
//  AutoFillExtension
//
//  Created by Benjamin Erhart on 25.06.25.
//

import Foundation

enum Errors: LocalizedError {

    case couldNotEncodeRpId
    case couldNotFindKey
    case couldNotFindPublicKey
    case keyInvalidLength(length: Int, firstByte: UInt8)
    case unknownCoseAlgo

    var localizedDescription: String {
        switch self {
        case .couldNotEncodeRpId:
            return "Could not encode Relying Party ID!"

        case .couldNotFindKey:
            return "Could not find key!"

        case .couldNotFindPublicKey:
            return "Could not find public key!"

        case .keyInvalidLength(let length, let firstByte):
            return "Raw key must be 64, 96 or 132 bytes long, or start with 0x04 and be 65, 97 or 133 bytes long; was \(length) bytes starting with \(firstByte)"

        case .unknownCoseAlgo:
            return "Failed to determine COSE EC algorithm. This should not be possible, please file a bug report."
        }
    }
}
