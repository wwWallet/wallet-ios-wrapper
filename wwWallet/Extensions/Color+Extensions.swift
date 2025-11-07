//
//  Color+Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 07.11.25.
//

import SwiftUI

extension Color {

    init?(hex: any StringProtocol) {
        var int: UInt64 = 0
        Scanner(string: String(hex)).scanHexInt64(&int)

        let a, r, g, b: UInt64

        switch hex.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = (int >> 4 & 0xf) * 17
            b = (int & 0xf) * 17

        case 6:
            a = 255
            r = int >> 16
            g = int >> 08 & 0xff
            b = int & 0xff

        case 8:
            a = int >> 24
            r = int >> 16 & 0xff
            g = int >> 08 & 0xff
            b = int & 0xff

        default:
            return nil
        }

        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
