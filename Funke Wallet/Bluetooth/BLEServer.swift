//
//  BLEServer.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-12-04.
//

import CoreBluetooth
import OSLog

class BLEServer: NSObject {

    static let shared = BLEServer()

    private var characteristics = DefaultCharacteristics()
    private let perihperalManager = CBPeripheralManager()
    private let log = Logger(for: BLEServer.self)

    private override init() {
        super.init()

        perihperalManager.delegate = self
    }

    func start() {
        let service = CBMutableService(type: characteristics.serviceUuid, primary: true)
        service.characteristics = characteristics.characteristics()

        perihperalManager.add(service)
        perihperalManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [characteristics.serviceUuid],
            CBAdvertisementDataLocalNameKey: characteristics.serviceUuid.uuidString])
    }

    func disconnect() {
        // TODO: Why is this empty?
    }
}


extension BLEServer: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log.debug("CBPeripheralManager state: \(peripheral.state.rawValue)")

        switch peripheral.state {
        case .poweredOn:
            start()

        default:
            break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        log.debug("didReceiveRead requests: \(request)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log.debug("didReceiveWrite requests: \(requests)")
    }


    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        log.debug("CBPeripheralManager didAdd: \(service)\(error != nil ? "with error: \(error!)" : "")")
    }
}

struct DefaultCharacteristics {

    let serviceUuid = CBUUID(string: "00179c7a-eec6-4f88-8646-045fda9ac4d8")

    enum Mode {
        case mDocReader, mDoc

        var state: CBUUID {
            switch self {
            case .mDocReader:
                return CBUUID(string: "00000005-A123-48CE-896B-4C76973373E6")

            case .mDoc:
                return CBUUID(string: "00000001-A123-48CE-896B-4C76973373E6")
            }
        }

        var client2Server: CBUUID {
            switch self {
            case .mDocReader:
                return CBUUID(string: "00000006-A123-48CE-896B-4C76973373E6")

            case .mDoc:
                return CBUUID(string: "00000002-A123-48CE-896B-4C76973373E6")
            }
        }

        var server2Client: CBUUID {
            switch self {
            case .mDocReader:
                return CBUUID(string: "00000007-A123-48CE-896B-4C76973373E6")

            case .mDoc:
                return CBUUID(string: "00000003-A123-48CE-896B-4C76973373E6")
            }
        }
    }

    let mode: Mode = .mDocReader

    func characteristics() -> [CBMutableCharacteristic] {
        return [.init(type: mode.state, properties: [.notify, .writeWithoutResponse],
                      value: nil, permissions: [.writeable]),
                .init(type: mode.client2Server, properties: [.notify, .writeWithoutResponse],
                      value: nil, permissions: [.writeable]),
                .init(type: mode.server2Client, properties: [.notify],
                      value: nil, permissions: [.writeable])]
    }
}
