//
//  ContentView.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI

struct ContentView: View {
    @State var model = BridgeModel()
    
    var body: some View {
        VStack {
            WebView(url: URL(string: "https://funke.wwwallet.org")!, model: model)
        }
        .onOpenURL { url in
            model.openUrl(url)
        }
    }
}

#Preview {
    ContentView()
}
