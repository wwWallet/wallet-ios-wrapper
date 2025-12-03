//
//  Config.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 29.05.25.
//

import Foundation

extension Config {

    class var groupId: String {
        __groupId as String
    }

    class var baseDomain1: String {
        __baseDomain1 as String
    }

    class var baseDomain2: String {
        __baseDomain2 as String
    }

    class var baseDomain3: String {
        __baseDomain3 as String
    }

    class var baseDomain4: String {
        __baseDomain4 as String
    }

    class var baseDomains: [String] {
        [baseDomain1, baseDomain2, baseDomain3, baseDomain4]
    }

    class var baseDomain: String {
        if !registered {
            UserDefaults.standard.register(defaults: ["environment": "1"])
            registered = true
        }

        if let baseDomain = UserDefaults.standard.string(forKey: "environment"),
           !baseDomain.isEmpty,
           let idx = Int(baseDomain),
           idx >= 0 && idx < baseDomains.count
        {
            return baseDomains[idx]
        }

        return baseDomain2
    }

    private static var registered = false
}
