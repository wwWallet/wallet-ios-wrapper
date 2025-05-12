//
//  ContentView.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    
    @State var model = BridgeModel()
    @State var passkeyType: PasskeyType?
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("bypassSelectKeyType") var bypassSelectKeyType: Bool = false
    @AppStorage("useYubiKey") var useYubiKey: Bool = false
    @State var presentSelectKeyType: Bool = false

    var body: some View {
        ZStack {
            Color(red: 17/255, green: 25/255, blue: 40/255)
            VStack {
                if let passkeyType {
                    WebView(url: URL(string: "https://funke.wwwallet.org")!, model: model, passkeyType: passkeyType)
                        .onOpenURL { url in
                            model.openUrl(url)
                        }
                }
            }.padding(0)
        }
        .sheet(isPresented: $presentSelectKeyType) {
            VStack {
                Image(.wallet).resizable().scaledToFit().frame(width: 110)
                    .padding(.top, 20)
                Text("Select the authorization method to use. You can change your remembered choice later in the iOS Settings app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(15)
                VStack {
                    Button("Built-in passkey") {
                        passkeyType = .builtin
                        useYubiKey = false
                        presentSelectKeyType = false
                    }
                        .buttonStyle(.basicButton)
                    Button("YubiKey") {
                        passkeyType = .yubikey
                        useYubiKey = true
                        presentSelectKeyType = false
                    }
                        .bold()
                        .padding(.top, 15)
                    Spacer()
                    Toggle("Remember my choice", isOn: $bypassSelectKeyType)
                        .padding(.horizontal, 30)
                }
            }
            .padding()
            .presentationDetents([.medium])
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            if bypassSelectKeyType {
                passkeyType = useYubiKey ? .yubikey : .builtin
                print("select key type from settings")
            } else {
                presentSelectKeyType = true
            }

            Task {
                // Point the user at the passkeys auto-fill feature.
                await ASSettingsHelper.requestToTurnOnCredentialProviderExtension()
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
