//
//  YubiKeyConnection.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

@preconcurrency import YubiKit

class YubiKeyConnection: NSObject {
    
    var accessoryConnection: YKFAccessoryConnection?
    var nfcConnection: YKFNFCConnection?
    var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    
    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
            //        YubiKitManager.shared.startAccessoryConnection()
    }
    
    func connection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            YubiKitManager.shared.startNFCConnection()
        }
    }

    func connect() async -> any YKFConnectionProtocol {
        await withCheckedContinuation { continuation in
            connection { connection in
                continuation.resume(returning: connection)
            }
        }
    }
}

extension YubiKeyConnection: YKFManagerDelegate {
    func didConnectNFC(_ connection: YKFNFCConnection) {
       nfcConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
    }
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
    }
}
