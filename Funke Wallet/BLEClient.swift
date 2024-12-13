//
//  BLEClient.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-12-04.
//

import CoreBluetooth

class BLEClient: NSObject {
    
    static let shared = BLEClient()
    
    let manager = CBCentralManager()
    var completionHandler: ((Any?, String?) -> Void)?
    var serviceUUID: CBUUID?
    var connectedPeripheral: CBPeripheral?
    var service: CBService?
    
    private override init() {
        super.init()
        manager.delegate = self
    }
    
    func startScanning(for serviceUUID: CBUUID, completionHandler: @escaping (Any?, String?) -> Void) {
        print("🔹 startScanning for \(serviceUUID)")
        self.serviceUUID = serviceUUID
        self.completionHandler = completionHandler
        manager.scanForPeripherals(withServices: [serviceUUID])
    }
    
    
    var receivedDataBuffer: Data?
    func receiveFromServer(completionHandler: @escaping (Any?, String?) -> Void) {
        print("🔹 receiveFromServer")
        self.receivedDataBuffer = Data()
        self.completionHandler = completionHandler
    }
    
    func sendToServer(data: Data, completionHandler: @escaping (Any?, String?) -> Void) {
        print("🔹 sendToServer \(data.hexString)")
        if let characteristics = service?.characteristics, let client2ServerChar = characteristics.filter({ $0.uuid == DefaultCharacteristics.MdocReaderService.client2Server.cbuuid }).first {
            print("🔹 periperhal didWriteValueFor stateChar: \(client2ServerChar.uuid)")
            connectedPeripheral?.writeValue(data, for: client2ServerChar, type: .withoutResponse)
            completionHandler(true, nil)
        } else {
            completionHandler(false, nil)
        }
    }
    
    func disconnect() {
        print("🔹 disconnect")
        guard let connectedPeripheral else { return }
//        manager.cancelPeripheralConnection(connectedPeripheral)
//        self.connectedPeripheral = nil
    }
    
}
    




extension BLEClient: CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("🔹 centralManager didDiscover peripheral:\(peripheral)")
        self.connectedPeripheral = peripheral
        peripheral.delegate = self
        manager.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let serviceUUID else { fatalError(); }
        print("🔹 centralManager didConnect peripheral:\(peripheral)")
        peripheral.discoverServices([serviceUUID])
        self.connectedPeripheral = peripheral
        self.completionHandler?(true, nil)
        self.completionHandler = nil
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔹 CBCentralManager state:\(central.state)")
    }
}


extension BLEClient: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("🔹 peripheral didDiscoverServices:\(peripheral.services) error:\(error)")
        guard let serviceUUID, let services = peripheral.services, let service = (services.filter { $0.uuid == serviceUUID }).first else { return }
        peripheral.discoverCharacteristics(nil, for: service)
        self.service = service
        print("selected service:\(service)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        print("🔹 peripheral didDiscoverCharacteristicsFor service:\(service), characteristics: \(service.characteristics) error:\(error)")
        if let characteristics = service.characteristics, let server2ClientChar = characteristics.filter({ $0.uuid == DefaultCharacteristics.MdocReaderService.server2Client.cbuuid }).first {
            peripheral.setNotifyValue(true, for: server2ClientChar)
        }
        
        if let characteristics = service.characteristics, let client2ServerChar = characteristics.filter({ $0.uuid == DefaultCharacteristics.MdocReaderService.client2Server.cbuuid }).first {
            peripheral.setNotifyValue(true, for: client2ServerChar)
        }
        
        if let characteristics = service.characteristics, let stateChar = characteristics.filter({ $0.uuid == DefaultCharacteristics.MdocReaderService.state.cbuuid }).first {
            peripheral.setNotifyValue(true, for: stateChar)
            print("🔹 periperhal didWriteValueFor: 0x01 for stateChar: \(stateChar.uuid)")
            peripheral.writeValue(Data([0x01]), for: stateChar, type: .withoutResponse)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("🔹 didUpdateNotificationStateFor characteristic: \(characteristic), value: \(characteristic.value?.hexString ?? "nil")")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("🔹 didWriteValueFor characteristic: \(characteristic), value: \(characteristic.value?.hexString ?? "nil")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        print("🔹 didUpdateValueFor characteristic: \(characteristic), value: \(characteristic.value?.hexString ?? "nil")")
        guard characteristic.uuid == DefaultCharacteristics.MdocReaderService.server2Client.cbuuid else { print("🐞 Received data from wrong peripheral!"); return }
        guard let receivedData = characteristic.value, let header = receivedData.first else { print("🐞 Missing data from peripheral!"); return }
        self.receivedDataBuffer?.append(receivedData.dropFirst())
        if header == 0x00 {
            print("🔹 received last packet")
            guard let completionHandler = self.completionHandler,
                  let data = self.receivedDataBuffer,
                  let jsonData = try? JSONSerialization.data(withJSONObject: [UInt8](Data([0x00]) + data), options: [.fragmentsAllowed]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { print("🐞 Bad state for receiving data!"); return }
            print("🔹 send to web view: \"\(jsonString)\"")
            completionHandler("\"\(jsonString)\"", nil)
            self.completionHandler = nil
        } else {
            print("🔹 more packets to receive")
        }
    }
}
