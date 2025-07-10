//
//  URL+Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 10.07.25.
//

import Foundation

extension URL {

    static var groupFolder: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Config.groupId)
    }
}
