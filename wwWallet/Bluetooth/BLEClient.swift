//
//  BLEClient.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-04.
//

import CoreBluetooth
import OSLog

class BLEClient: NSObject {

    static let shared = BLEClient()

    private let manager = CBCentralManager()
    private var completionHandler: ((Any?) -> Void)?
    private var serviceUuid: CBUUID?
    private var connectedPeripheral: CBPeripheral?
    private var service: CBService?
    private var receivedDataBuffer: Data?
    private let log = Logger(for: BLEClient.self)


    private override init() {
        super.init()

        manager.delegate = self
    }


    func startScanning(for serviceUuid: CBUUID, completionHandler: @escaping (Any?) -> Void) {
        log.debug("🔹 startScanning for \(serviceUuid)")

        self.serviceUuid = serviceUuid
        self.completionHandler = completionHandler

        manager.scanForPeripherals(withServices: [serviceUuid])
    }

    func startScanning(for serviceUuid: CBUUID) async -> Any? {
        await withCheckedContinuation { continuation in
            startScanning(for: serviceUuid) { reply in
                continuation.resume(returning: reply)
            }
        }
    }

    func receiveFromServer(completionHandler: @escaping (Any?) -> Void) {
        log.debug("🔹 receiveFromServer")

        self.receivedDataBuffer = Data()
        self.completionHandler = completionHandler
    }

    func receiveFromServer() async -> Any? {
        await withCheckedContinuation { continuation in
            receiveFromServer { reply in
                continuation.resume(returning: reply)
            }
        }
    }

    func sendToServer(data: Data, completionHandler: @escaping (Any?) -> Void) {
        log.debug("🔹 sendToServer \(data.hexString)")

        if let client2ServerChar = service?.characteristics?.filter({ $0.uuid == DefaultCharacteristics.Mode.mDocReader.client2Server }).first
        {
            log.debug("🔹 periperhal didWriteValueFor stateChar: \(client2ServerChar.uuid)")

            connectedPeripheral?.writeValue(data, for: client2ServerChar, type: .withoutResponse)

            completionHandler(true)
        }
        else {
            completionHandler(false)
        }
    }

    func sendToServer(data: Data) async -> Any? {
        await withCheckedContinuation { continuation in
            sendToServer(data: data) { reply in
                continuation.resume(returning: reply)
            }
        }
    }

    func disconnect() {
        log.debug("🔹 disconnect")

        guard let connectedPeripheral else {
            return
        }

//        manager.cancelPeripheralConnection(connectedPeripheral)
//        self.connectedPeripheral = nil
    }
}


extension BLEClient: CBCentralManagerDelegate {

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log.debug("🔹 centralManager didDiscover peripheral: \(peripheral)")

        connectedPeripheral = peripheral
        peripheral.delegate = self

        manager.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let serviceUuid else {
            return log.error("serviceUuid is nil")
        }

        log.debug("🔹 centralManager didConnect peripheral: \(peripheral)")

        peripheral.discoverServices([serviceUuid])

        connectedPeripheral = peripheral
        completionHandler?(true)
        completionHandler = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log.debug("🔹 CBCentralManager state: \(central.state.rawValue)")
    }
}


extension BLEClient: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        log.debug("🔹 peripheral didDiscoverServices: \(peripheral.services?.description ?? "(nil)") error:\(error)")

        guard let serviceUuid,
              let service = peripheral.services?.filter({ $0.uuid == serviceUuid }).first
        else {
            return
        }

        peripheral.discoverCharacteristics(nil, for: service)
        self.service = service

        log.debug("selected service:\(service)")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        log.debug("🔹 peripheral didDiscoverCharacteristicsFor service:\(service), characteristics: \(service.characteristics?.description ?? "(nil)") error:\(error)")

        if let server2ClientChar = service.characteristics?.filter({ $0.uuid == DefaultCharacteristics.Mode.mDocReader.server2Client }).first
        {
            peripheral.setNotifyValue(true, for: server2ClientChar)
        }

        if let client2ServerChar = service.characteristics?.filter({ $0.uuid == DefaultCharacteristics.Mode.mDocReader.client2Server }).first
        {
            peripheral.setNotifyValue(true, for: client2ServerChar)
        }

        if let stateChar = service.characteristics?.filter({ $0.uuid == DefaultCharacteristics.Mode.mDocReader.state }).first
        {
            peripheral.setNotifyValue(true, for: stateChar)

            log.debug("🔹 periperhal didWriteValueFor: 0x01 for stateChar: \(stateChar.uuid)")

            peripheral.writeValue(Data([0x01]), for: stateChar, type: .withoutResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        log.debug("🔹 didUpdateNotificationStateFor characteristic: \(characteristic), value: \(characteristic.value?.hexString ?? "(nil)")")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        log.debug("🔹 didWriteValueFor characteristic: \(characteristic), value: \(characteristic.value?.hexString ?? "(nil)")")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        log.debug("🔹 didUpdateValueFor characteristic: \(characteristic), value: \(characteristic.value?.hexString ?? "(nil)")")

        guard characteristic.uuid == DefaultCharacteristics.Mode.mDocReader.server2Client
        else {
            return log.error("🐞 Received data from wrong peripheral!")
        }

        guard let receivedData = characteristic.value,
                let header = receivedData.first
        else {
            return log.error("🐞 Missing data from peripheral!")
        }

        receivedDataBuffer?.append(receivedData.dropFirst())

        if header == 0x00 {
            log.debug("🔹 received last packet")

            guard let completionHandler = completionHandler,
                  let data = receivedDataBuffer,
                  let jsonData = try? JSONSerialization.data(withJSONObject: [UInt8](Data([0x00]) + data), options: [.fragmentsAllowed]),
                  let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                return log.error("🐞 Bad state for receiving data!")
            }

            log.debug("🔹 send to web view: \"\(jsonString)\"")

            completionHandler("\"\(jsonString)\"")

            self.completionHandler = nil
        }
        else {
            log.debug("🔹 more packets to receive")
        }
    }
}
