//
//  YKFFIDO2Session+Extensions.swift
//  Funke Wallet
//
//  Created by Benjamin Erhart on 11.04.25.
//

import Foundation
import YubiKit

extension YKFFIDO2Session {

    func makeCredential(
        with clientDataHash: Data,
        rp: YKFFIDO2PublicKeyCredentialRpEntity,
        user: YKFFIDO2PublicKeyCredentialUserEntity,
        pubKeyCredParams: [Any],
        excludeList: [Any]? = nil,
        options: [AnyHashable: Any]? = nil,
        extensions: [AnyHashable: Any]? = nil
    ) async throws -> (response: YKFFIDO2MakeCredentialResponse, extensionResult: [AnyHashable: Any])
    {
        try await withCheckedThrowingContinuation { continuation in
            makeCredential(
                withClientDataHash: clientDataHash,
                rp: rp,
                user: user,
                pubKeyCredParams: pubKeyCredParams,
                excludeList: excludeList,
                options: options,
                extensions: extensions
            ) { response, extensionResult, error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
                else {
                    continuation.resume(returning: (response!, extensionResult!))
                }
            }
        }
    }

    func getAssertion(
        with clientDataHash: Data,
        rpId: String,
        allowList: [Any]? = nil,
        options: [AnyHashable: Any]? = nil,
        extensions: [AnyHashable: Any]? = nil
    ) async throws -> YKFFIDO2GetAssertionResponse
    {
        try await withCheckedThrowingContinuation { continuation in
            getAssertionWithClientDataHash(
                clientDataHash,
                rpId: rpId,
                allowList: allowList,
                options: options,
                extensions: extensions
            ) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                }
                else {
                    continuation.resume(returning: response!)
                }
            }
        }
    }
}
