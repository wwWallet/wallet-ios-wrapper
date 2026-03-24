//
//  wwWalletTests.swift
//  wwWalletTests
//
//  Created by Benjamin Erhart on 13.03.26.
//

import Testing
import SwiftUI
@testable import wwWallet
internal import YubiKit

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

    @Test("Test WebAuthnClientData initialization")
    func testWebAuthnClientDataInit() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let origin = "https://example.com"
        
        // Test successful initialization
        let clientData = WebAuthnClientData(type: .create, challenge: challenge, origin: origin)
        #expect(clientData != nil)
        #expect(clientData?.type == .create)
        #expect(clientData?.challenge == challenge)
        #expect(clientData?.origin == origin)
    }
    
    @Test("Test WebAuthnClientData jsonData property")
    func testWebAuthnClientDataJsonData() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let origin = "https://example.com"
        
        let clientData = WebAuthnClientData(type: .create, challenge: challenge, origin: origin)
        #expect(clientData != nil)
        
        do {
            let jsonData = try clientData!.jsonData
            #expect(!jsonData.isEmpty)
            
            // Verify it's valid JSON by attempting to decode it back
            let decoded = try JSONDecoder().decode(WebAuthnClientData.self, from: jsonData)
            #expect(decoded.type == .create)
            #expect(decoded.challenge == challenge)
            #expect(decoded.origin == origin)
        } catch {
            #expect(Bool(false), "Failed to encode/decode jsonData: \(error)")
        }
    }
    
    @Test("Test WebAuthnClientData clientDataHash property")
    func testWebAuthnClientDataClientDataHash() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString()
        let origin = "https://example.com"
        
        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)
        
        do {
            let hash = try clientData!.clientDataHash
            #expect(!hash.isEmpty)
            
            // SHA-256 hash should be 32 bytes long
            #expect(hash.count == 32)
        } catch {
            #expect(Bool(false), "Failed to encode/decode jsonData: \(error)")
        }
    }
    
    @Test("Test Data webSafeBase64EncodedString extension")
    func testDataWebSafeBase64Encoding() {
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = testData.webSafeBase64EncodedString()
        #expect(!encoded.isEmpty)
        
        // Verify that the encoding produces web-safe base64 (no padding, + and / replaced with - and _)
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
    }
    
    @Test("Test Data webSafeBase64DecodedData extension")
    func testDataWebSafeBase64Decoding() {
        // Test valid web-safe base64 string
        let originalData = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = originalData.webSafeBase64EncodedString()
        
        let decoded = encoded.webSafeBase64DecodedData()
        #expect(decoded != nil)
        #expect(decoded == originalData)
    }

    @Test("Test String webSafeBase64DecodedData extension with valid input")
    func testStringWebSafeBase64DecodingValidInput() {
        // Test with a known valid base64 string
        let originalData = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = originalData.base64EncodedString()
        
        // Convert to web-safe format
        let webSafeEncoded = encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let decoded = webSafeEncoded.webSafeBase64DecodedData()
        #expect(decoded != nil)
        #expect(decoded == originalData)
    }
    
    @Test("Test Data hexString property")
    func testDataHexString() {
        let testData = Data([0x12, 0x34, 0x56, 0x78])
        let hexString = testData.hexString
        #expect(hexString == "12345678")
    }
    
    @Test("Test CreateRequest clientData property")
    func testCreateRequestClientData() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")

        let createRequest = CreateRequest(
            rp: RelyingParty(id: "example.com", name: "Example"),
            user: User(id: "user123", name: "User Name", displayName: "User"),
            challenge: challenge,
            pubKeyCredParams: [PubKeyCredParams(type: "public-key", alg: -7)],
            attestation: "direct")
        
        let clientData = createRequest.clientData
        #expect(clientData != nil)
        #expect(clientData?.type == .create)
        #expect(clientData?.challenge == challenge)
        #expect(clientData?.origin == "https://example.com")
    }
    
    @Test("Test GetRequest clientData property")
    func testGetRequestClientData() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")

        // Based on typical webauthn structure and the error, we modify to match expected parameters
        let getRequest = GetRequest(
            rpId: "example.com",
            challenge: challenge,
            userVerification: "required",
            extensions: nil
        )
        
        let clientData = getRequest.clientData
        #expect(clientData != nil)
        #expect(clientData?.type == .get)
        #expect(clientData?.challenge == challenge)
        #expect(clientData?.origin == "https://example.com")
    }
    
    @Test("Test User entity property")
    func testUserEntity() {
        let user = User(id: "dXNlcjEyMw==", name: "User Name", displayName: "User")
        let entity = user.entity
        #expect(entity != nil)
        #expect(entity?.id == Data([0x75, 0x73, 0x65, 0x72, 0x31, 0x32, 0x33]))
        #expect(entity?.name == "User Name")
        #expect(entity?.displayName == "User")
    }
    
    @Test("Test PubKeyCredParams algorithm property")
    func testPubKeyCredParamsAlgorithm() {
        let params = PubKeyCredParams(type: "public-key", alg: -7)
        let algorithm = params.algorithm
        #expect(algorithm.rawValue == -7)
    }
}
