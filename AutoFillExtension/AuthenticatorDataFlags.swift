//
//  AuthenticatorDataFlags.swift
//  AutoFillExtension
//
//  Created by Benjamin Erhart on 25.06.25.
//

import Foundation

struct AuthenticatorDataFlags {

    enum Errors: LocalizedError {

        case invalidCombination(UInt8)

        var localizedDescription: String {
            switch self {
            case .invalidCombination(let value):
                return "Flag combination BE=0, BS=1 is invalid: \(value)"
            }
        }
    }

    private class Bitmasks {
        static let UP: UInt8 = 0x01
        static let UV: UInt8 = 0x04
        static let BE: UInt8 = 0x08
        static let BS: UInt8 = 0x10
        static let AT: UInt8 = 0x40
        static let ED : UInt8 = 0x80

        // Reserved bits
        static let RFU1 : UInt8 = 0x02
        static let RFU2 : UInt8 = 0x20
    }

    private(set) var value: UInt8

    /**
     User Present
     */
    var UP: Bool {
        get {
            (value & Bitmasks.UP) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.UP) : (value & ~Bitmasks.UP)
        }
    }

    /**
     User Verified
     */
    var UV: Bool {
        get {
            (value & Bitmasks.UV) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.UV) : (value & ~Bitmasks.UV)
        }
    }

    /**
     Backup eligible: the credential can and is allowed to be backed up.

     NOTE that this is only a hint and not a guarantee, unless backed by a trusted authenticator attestation.

     <https://w3c.github.io/webauthn/#authdata-flags-be>

     @DeprecationSummary {
        EXPERIMENTAL: This feature is from a not yet mature standard; it could change as the standard matures.
     }
     */
    var BE: Bool {
        get {
            (value & Bitmasks.BE) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.BE) : (value & ~Bitmasks.BE)
        }
    }

    /**
     Backup status: the credential is currently backed up.

     NOTE that this is only a hint and not a guarantee, unless backed by a trusted authenticator attestation.

     <https://w3c.github.io/webauthn/#authdata-flags-bs>

     @DeprecationSummary {
         EXPERIMENTAL: This feature is from a not yet mature standard; it could change as the standard matures.
     }
     */
    var BS: Bool {
        get {
            (value & Bitmasks.BS) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.BS) : (value & ~Bitmasks.BS)
        }
    }

    /**
     Attested credential data present.
     */
    var AT: Bool {
        get {
            (value & Bitmasks.AT) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.AT) : (value & ~Bitmasks.AT)
        }
    }

    /**
     Extension data present.
     */
    var ED: Bool {
        get {
            (value & Bitmasks.ED) != 0
        }
        set {
            value = newValue ? (value | Bitmasks.ED) : (value & ~Bitmasks.ED)
        }
    }

    init(value: UInt8 = 0x00) throws {
        self.value = value

        if BS && !BE {
            throw Errors.invalidCombination(value)
        }
    }
}
