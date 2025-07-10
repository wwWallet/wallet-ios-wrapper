//
//  UUID+Extensions.swift
//  AutoFillExtension
//
//  Created by Benjamin Erhart on 29.05.25.
//

import Foundation

extension UUID {

    static func from(data: Data) -> UUID? {
        guard data.count == MemoryLayout<UUID>.size else {
            return nil
        }

        return data.withUnsafeBytes {
            $0.load(as: UUID.self)
        }
    }

    var bytes: [UInt8] {
        [uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7,
         uuid.8, uuid.9, uuid.10, uuid.11, uuid.12, uuid.13, uuid.14, uuid.15]
    }

    var data: Data {
        Data(bytes)
    }
}
