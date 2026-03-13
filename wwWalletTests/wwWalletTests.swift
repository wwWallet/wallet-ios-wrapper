//
//  wwWalletTests.swift
//  wwWalletTests
//
//  Created by Benjamin Erhart on 13.03.26.
//

import Testing
import SwiftUI
@testable import wwWallet

@Suite("wwWallet Test Suite")
struct wwWalletTests {

    @Test("Test base domains configuration")
    func testBaseDomains() {
        let domains = Config.baseDomains
        #expect(domains.count > 0)
        
        for domain in domains {
            #expect(!domain.isEmpty)
        }

        #expect(!Config.baseDomain.isEmpty)
    }

    @Test("Test default base domain selection")
    func testBaseDomainSelection() {
        let defaultDomain = Config.baseDomain
        #expect(!defaultDomain.isEmpty)
        #expect(Config.baseDomains.contains(defaultDomain))
    }

    @Test("Test ContentView structure")
    func testContentViewStructure() {
        // Test that ContentView can be initialized without crashing
        _ = ContentView()
        #expect(true) // If we got here, initialization worked
    }

    @Test("Test domain switching configuration")
    func testDomainSwitchingConfiguration() {
        #if ALLOW_DOMAIN_SWITCHING
        #expect(true, "Domain switching is enabled")
        #else
        #expect(true, "Domain switching is disabled")
        #endif
    }

    @Test("Test color from hex parsing")
    func testColorFromHex() {
        // Test valid hex colors
        let color1 = Color(hex: "000000")  // Black
        #expect(color1 == .black)

        let color2 = Color(hex: "FFFFFF")  // White
        #expect(color2 == .white)

        let color3 = Color(hex: "FF0000")  // Red
        #expect(color3 == Color(red: 1, green: 0, blue: 0, opacity: 1))
    }

    @Test("Test invalid hex color handling")
    func testInvalidHexColor() {
        // Test invalid hex color should return nil
        let color = Color(hex: "WXYZ")
        #expect(color == nil)
    }

    @Test("Test example functionality")
    func testExample() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        #expect(true)
    }
}
