//
//  ContentView.swift
//  Funke Wallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI

struct ContentView: View {
    
    @State var model = BridgeModel()
    @State var passkeyType: PasskeyType?
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("bypassSelectKeyType") var bypassSelectKeyType: Bool = false
    @AppStorage("useYubiKey") var useYubiKey: Bool = false
    @State var showRememberMyChoiceAlert: Bool = false

    var body: some View {
        VStack {
            if let passkeyType {
                WebView(url: URL(string: "https://funke.wwwallet.org")!, model: model, passkeyType: passkeyType)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .onOpenURL { url in
                        model.openUrl(url)
                    }
            } else {
                VStack {
                    Text("Select key type").font(.title).bold()
                        .padding(.top, 30)
                    Button("YubiKey") { passkeyType = .yubikey; useYubiKey = true }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    Button("Builtin Passkey") { passkeyType = .builtin; useYubiKey = false }
                        .buttonStyle(.borderedProminent)
                    Toggle("Remember my choice", isOn: $bypassSelectKeyType)
                        .padding(30)
                }
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 15))
                .padding(30)
            }
        }
        .onChange(of: bypassSelectKeyType) {
            showRememberMyChoiceAlert = bypassSelectKeyType
        }
        .alert("Notice", isPresented: $showRememberMyChoiceAlert) {
            Button("OK") { }
        } message: {
            Text("The select key type option will not be visible at application startup if selected. If you wish to change the key type in the future, you must do so in the Funke Wallet section of the iOS Settings app.")
        }
        .onAppear {
            if bypassSelectKeyType {
                passkeyType = useYubiKey ? .yubikey : .builtin
                print("select key type from settings")
            }
        }
        .onChange(of: scenePhase) {
            print("scenePhase: \(scenePhase)")
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
