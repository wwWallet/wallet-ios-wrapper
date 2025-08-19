//
//  wwWalletApp.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
import OSLog

@main
struct wwWalletApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Logger(with: self).info("Environment: \(Config.baseDomain)")
                }
        }
    }
}
