//
//  BluetoothBridge.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 05.02.26.
//

import Foundation
import OSLog
import WebKit
import CoreBluetooth

class BluetoothBridge: NSObject, CBCentralManagerDelegate, WKScriptMessageHandlerWithReply {

    private enum Handlers: String, CaseIterable {
        case availability = "__bt_availability"
        case requestDevice = "__bt_request_device"
    }

    private let log = Logger(with: BluetoothBridge.self)

    private var btManager: CBCentralManager!

    private let queue: DispatchQueue = .global(qos: .userInitiated)


    init(_ ucc: WKUserContentController) {
        super.init()

        btManager = .init(delegate: self, queue: queue, options: [
            CBCentralManagerOptionShowPowerAlertKey: NSNumber(booleanLiteral: false) ])

        for handler in Handlers.allCases {
            ucc.addScriptMessageHandler(self, contentWorld: .page, name: handler.rawValue)
        }
    }


    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log.debug("#centralManagerDidUpdateState: \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // TODO
    }


    // MARK: WKScriptMessageHandlerWithReply

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        guard let handler = Handlers(rawValue: message.name) else {
            log.error("Handler \(message.name) not found!")
            return (nil, "Handler \(message.name) not found!")
        }

        log.debug("#didReceive: \(handler.rawValue)(\(message.stringBody ?? "nil"))")

        switch handler {
        case .availability:
            return (btManager.state == .poweredOn, nil)

        case .requestDevice:
            btManager.scanForPeripherals(withServices: nil)
            return (nil, nil)
        }
    }
}
