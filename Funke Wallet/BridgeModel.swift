//
//  BridgeModel.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-29.
//


import SwiftUI
import YubiKit

@Observable class BridgeModel {
    
    var receivedMessage: String?
    var sentMessage: String?
    let connection = YubiKeyConnection()
    
    var loadURLCallback: ((URL) -> Void)?
    
    func openUrl(_ url: URL) {
        loadURLCallback?(url)
    }
    
    func didReceiveCreate(message: [String: Any], replyHandler: @escaping (Any?, String?) -> Void) {
       print(message)
        
        connection.connection { connection in
            connection.fido2Session { session, error in
                guard let session else { fatalError() }
                session.verifyPin("123456") { result in
                    guard result == nil else { fatalError(result!.localizedDescription) }
                    
                    guard let request = message["request"] as? [String: Any], let requestRp = request["rp"] as? [String: Any] else { fatalError() }
                    guard let challengeString = request["challenge"] as? String, let challenge = challengeString.webSafeBase64DecodedData() else { fatalError() }
                    let clientData = YKFWebAuthnClientData(type: .create, challenge: challenge, origin: #"https://"# + (requestRp["id"] as! String))!
                    let rp = YKFFIDO2PublicKeyCredentialRpEntity()
                    rp.rpId = requestRp["id"] as! String
                    rp.rpName = requestRp["name"] as! String
                    let user = YKFFIDO2PublicKeyCredentialUserEntity()
                    
                    guard let requestUser = request["user"] as? [String: String],
                          let userId = requestUser["id"],
                          let userIdData = userId.webSafeBase64DecodedData(),
                          let displayName = requestUser["displayName"],
                          let name = requestUser["name"] else { fatalError() }
                    user.userId = userIdData
                    user.userName = name
                    user.userDisplayName = displayName
                    
                    guard let algorithms = request["pubKeyCredParams"] as? [[String: Any]] else { fatalError() }
                    var params = [YKFFIDO2PublicKeyCredentialParam]()
                    algorithms.forEach { algorithm in
                        let param = YKFFIDO2PublicKeyCredentialParam()
                        param.alg = algorithm["alg"] as! Int
                        params.append(param)
                    }
                    
                    var exludeList: [YKFFIDO2PublicKeyCredentialDescriptor]? = nil
                    if let excludeListDict = request["excludeCredentials"] as? [[String: Any]] {
                        exludeList = [YKFFIDO2PublicKeyCredentialDescriptor]()
                        excludeListDict.forEach { exclude in
                            let descriptor = YKFFIDO2PublicKeyCredentialDescriptor()
                            descriptor.credentialId = (exclude["id"] as! String).webSafeBase64DecodedData()!
                            let credType = YKFFIDO2PublicKeyCredentialType()
                            credType.name = "public-key"
                            descriptor.credentialType = credType
                            exludeList?.append(descriptor)
                        }
                    }
                    
                    var extensions: [String: Any]? = nil
                    if let extensionsDict = request["extensions"] as? [String: Any] {
                        extensions = extensionsDict
                    }
                    
                    var options: [String: Bool]? = nil
                    if let authenticatorSelection = request["authenticatorSelection"] as? [String: Any] {
                        if authenticatorSelection["residentKey"] as! String == "preferred"
                            || authenticatorSelection["residentKey"] as! String == "required"
                            || authenticatorSelection["requireResidentKey"] as! Bool == true
                        {
                            options = ["rk": true]
                        }
                    }
                    
                    session.makeCredential(withClientDataHash: clientData.clientDataHash!, rp: rp, user: user, pubKeyCredParams: params, excludeList: exludeList, options: options, extensions: extensions) { response, extensionResult, error in
                        
                        if let extensionResult, let response {
                            var replyDict: [String: Any] = ["0": "success", "2": "create"]
                            
                            
                            var responseDict = [String: Any]()
                            responseDict["clientDataJSON"] = clientData.jsonData!.webSafeBase64EncodedString()
                            responseDict["transports"] = ["nfc", "usb"]
                            responseDict["authenticatorData"] = response.authData.webSafeBase64EncodedString()
                            responseDict["attestationObject"] = response.webauthnAttestationObject.webSafeBase64EncodedString()

                            let coseEncodedCredentialPublicKey =  response.authenticatorData!.coseEncodedCredentialPublicKey!
                            let cosePublicKeyCborMap = YKFCBORDecoder.decodeDataObject(from: coseEncodedCredentialPublicKey) as! YKFCBORMap
                            let cosePublicKeyMap = YKFCBORDecoder.convertCBORObject(toFoundationType: cosePublicKeyCborMap) as! [Int: Any]
                            responseDict["publicKeyAlgorithm"] = cosePublicKeyMap[3] as! Int
// Commented out for now since wwwallet doesn't use getPublicKey
//                            switch cosePublicKeyMap[1] as! Int {
//                            case 1:
//                                guard cosePublicKeyMap[-1] as! Int == 6 else { fatalError() }
//                                responseDict["publicKey"] = (cosePublicKeyMap[-2] as! Data).webSafeBase64EncodedString()
//                            case 2:
//                                break;
////                                fatalError("Not implemented") // TODO: To be implemented
//                            case 3:
//                                fatalError("Not implemented") // TODO: To be implemented
//                            default: fatalError()
//                            }
                            var credentialDict = [String: Any]()
                            credentialDict["response"] = responseDict
                            credentialDict["id"] = response.authenticatorData!.credentialId!.webSafeBase64EncodedString()
                            credentialDict["rawId"] = response.authenticatorData!.credentialId!.webSafeBase64EncodedString()
                            credentialDict["type"] = "public-key"
                            credentialDict["clientExtensionResults"] = extensionResult
                            credentialDict["authenticatorAttachment"] = "cross-platform" // TODO: hardcoded for now
                            replyDict["1"] = credentialDict
                            let jsonReplyData = try! JSONSerialization.data(withJSONObject: replyDict)
                            let jsonReplyString = String(data: jsonReplyData, encoding: .utf8)
                            print(jsonReplyString)
                            replyHandler(["data": jsonReplyString], nil)
                        } else {
                            if let error, (error as NSError).code == 0x19 {
                                print("0x19 error!")
                                replyHandler(nil, "0x19")
                            } else {
                                replyHandler(nil, "-1")
                            }
                        }
                        YubiKitManager.shared.stopNFCConnection()
                    }
                    
                }
                print("Got connection: \(connection)")
            }
        }
    }
    
    func didReceiveGet(message: [String: Any], replyHandler: @escaping (Any?, String?) -> Void) {
        print("didReceiveGet: \n \(message)")
        
        connection.connection { connection in
            connection.fido2Session { session, error in
                guard let session else { fatalError() }
                session.verifyPin("123456") { result in
                    guard result == nil else { fatalError(result!.localizedDescription) }
                    
                    guard let request = message["request"] as? [String: Any], let rpId = request["rpId"] as? String else { fatalError() }
                    guard let challengeString = request["challenge"] as? String, let challenge = challengeString.webSafeBase64DecodedData() else { fatalError() }
                    let clientData = YKFWebAuthnClientData(type: .get, challenge: challenge, origin: #"https://"# + rpId)!
                    
                    var exludeList: [YKFFIDO2PublicKeyCredentialDescriptor]? = nil
                    if let allowList = request["allowCredentials"] as? [[String: Any]] {
                        exludeList = [YKFFIDO2PublicKeyCredentialDescriptor]()
                        allowList.forEach { exclude in
                            let descriptor = YKFFIDO2PublicKeyCredentialDescriptor()
                            descriptor.credentialId = (exclude["id"] as! String).webSafeBase64DecodedData()!
                            let credType = YKFFIDO2PublicKeyCredentialType()
                            credType.name = "public-key"
                            descriptor.credentialType = credType
                            exludeList?.append(descriptor)
                        }
                    }
                    
                    var extensions: [String: Any]? = nil
                    if let extensionsDict = request["extensions"] as? [String: Any] {
                        extensions = extensionsDict
                    }
                    
                    session.getAssertionWithClientDataHash(clientData.clientDataHash!, rpId: rpId, allowList: exludeList, extensions: extensions) { response, error in
                    
                        if let response {
                            var replyDict: [String: Any] = ["0": "success", "2": "get"]
                            
                            
                            var responseDict = [String: Any]()
                            responseDict["clientDataJSON"] = clientData.jsonData!.webSafeBase64EncodedString()
                            responseDict["authenticatorData"] = response.authData.webSafeBase64EncodedString()
                            responseDict["signature"] = response.signature.webSafeBase64EncodedString()
                            if let user = response.user {
                                responseDict["userHandle"] = user.userId.webSafeBase64EncodedString()
                            }
                            
                            var credentialDict = [String: Any]()
                            credentialDict["response"] = responseDict
                            credentialDict["id"] = response.credential!.credentialId.webSafeBase64EncodedString()
                            credentialDict["rawId"] = response.credential!.credentialId.webSafeBase64EncodedString()
                            credentialDict["type"] = "public-key"
                            credentialDict["clientExtensionResults"] = response.extensionsOutput
                            credentialDict["authenticatorAttachment"] = "cross-platform"
                            replyDict["1"] = credentialDict
                            
                            let jsonReplyData = try! JSONSerialization.data(withJSONObject: replyDict)
                            let jsonReplyString = String(data: jsonReplyData, encoding: .utf8)
                            print(jsonReplyString)
                            replyHandler(["data": jsonReplyString], nil)
                        } else {
                            replyHandler(nil, "-1")
                        }
                        YubiKitManager.shared.stopNFCConnection()
                    }
                    
                }
                print("Got connection: \(connection)")
            }
        }
    }
    
//    func receive(message: String) {
//        receivedMessage = message
//        print("Received: \(message)")
//        connection.connection { connection in
//            print("Got connection: \(connection)")
//        }
//    }
//
//    var sendCallback: ((String) -> Void)?
//    func send(message: String) {
//        sentMessage = message
//        sendCallback?(message)
//        print("Sent: \(message)")
//    }
}
