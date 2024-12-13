//
//  BLEServer.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-12-04.
//

import CoreBluetooth

class BLEServer: NSObject {
    static let shared = BLEServer()
    
    private var serviceCharacteristics = DefaultCharacteristics()

    let perihperalManager = CBPeripheralManager()
    
    private override init() {
        super.init()
        perihperalManager.delegate = self
    }
    
    func start() {
        let service = CBMutableService(type: CBUUID(nsuuid: serviceCharacteristics.serviceUUID), primary: true)
        service.characteristics = serviceCharacteristics.characteristics()
        perihperalManager.add(service)
        perihperalManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(nsuuid: serviceCharacteristics.serviceUUID)], CBAdvertisementDataLocalNameKey: serviceCharacteristics.serviceUUID.uuidString])
    }
    
    func disconnect() {
        
    }
}


extension BLEServer: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("CBPeripheralManager state: \(peripheral.state)")
        switch peripheral.state {
        case .poweredOn:
            start()
        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("didReceiveRead requests: \(request)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("didReceiveWrite requests: \(requests)")
    }
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        print("CBPeripheralManager didAdd: \(service)\(error != nil ? "with error: \(error!)" : "")")
    }
}

struct DefaultCharacteristics {
    
    let serviceUUID = UUID(uuidString: "00179c7a-eec6-4f88-8646-045fda9ac4d8")!
    
    enum Mode {
        case mDocReader, mDoc
    }
    
    let mode: Mode = .mDocReader
    
    enum MdocService: String, Sendable {
        case state =         "00000001-A123-48CE-896B-4C76973373E6"
        case client2Server = "00000002-A123-48CE-896B-4C76973373E6"
        case server2Client = "00000003-A123-48CE-896B-4C76973373E6"
        
        var cbuuid: CBUUID { CBUUID(string: self.rawValue) }
    }
    
    enum MdocReaderService: String, Sendable {
        case state =         "00000005-A123-48CE-896B-4C76973373E6"
        case client2Server = "00000006-A123-48CE-896B-4C76973373E6"
        case server2Client = "00000007-A123-48CE-896B-4C76973373E6"
        
        var cbuuid: CBUUID { CBUUID(string: self.rawValue) }
    }
    
    func characteristics() -> [CBMutableCharacteristic] {
        switch mode {
        case .mDoc:
            return [CBMutableCharacteristic(type: MdocService.state.cbuuid, properties: [.notify, .writeWithoutResponse], value: nil, permissions: [.writeable]),
                    CBMutableCharacteristic(type: MdocService.client2Server.cbuuid, properties: [.notify, .writeWithoutResponse], value: nil, permissions: [.writeable]),
                    CBMutableCharacteristic(type: MdocService.server2Client.cbuuid, properties: [.notify], value: nil, permissions: [.writeable])]
        case .mDocReader:
            return [CBMutableCharacteristic(type: MdocReaderService.state.cbuuid, properties: [.notify, .writeWithoutResponse], value: nil, permissions: [.writeable]),
                    CBMutableCharacteristic(type: MdocReaderService.client2Server.cbuuid, properties: [.notify, .writeWithoutResponse], value: nil, permissions: [.writeable]),
                    CBMutableCharacteristic(type: MdocReaderService.server2Client.cbuuid, properties: [.notify], value: nil, permissions: [.writeable])]
        }
    }
    
}
