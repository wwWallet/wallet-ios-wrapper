//
//  Lock.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 10.07.25.
//

import Foundation

class Lock {

    enum Errors: Error {
        case lockFileCannotBeConstructed
        case lockFileCannotBeCreated
    }

    private static let file = URL.groupFolder?.appendingPathComponent("unlocked")

    class var isLocked: Bool {
        !((try? file?.checkResourceIsReachable()) ?? false)
    }

    class func lock() throws {
        guard let file = file else {
            throw Errors.lockFileCannotBeConstructed
        }

        try FileManager.default.removeItem(at: file)
    }

    class func unlock() throws {
        guard let file = file else {
            throw Errors.lockFileCannotBeConstructed
        }

        if !FileManager.default.createFile(atPath: file.path(), contents: nil) {
            throw Errors.lockFileCannotBeCreated
        }
    }

    private init() {
    }
}
