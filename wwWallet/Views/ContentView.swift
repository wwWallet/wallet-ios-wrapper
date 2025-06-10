//
//  ContentView.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
import AuthenticationServices
import OSLog

struct ContentView: View {
    
    @State var model = BridgeModel()

    @State var passkeyType = PasskeyType.builtin

    @Environment(\.scenePhase) var scenePhase

    @AppStorage("bypassSelectKeyType") var bypassSelectKeyType = false
    @AppStorage("useYubiKey") var useYubiKey = false

    @State var presentSelectKeyType = false

    var body: some View {
        ZStack {
            Color(red: 17/255, green: 25/255, blue: 40/255)
            VStack {
                WebView(
                    url: URL(string: "https://\(Config.baseDomain)")!,
                    model: model, passkeyType: passkeyType)
                    .onOpenURL { url in
                        let log = Logger(with: self)

                        if url.scheme == "haip",
                           var urlc = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        {
                            urlc.scheme = "https"

                            // There might be a piece, which the URLComponents
                            // parser wrongly identified as the domain, not the path.
                            // Preserve that, before setting the host.
                            if let host = urlc.host,
                               !host.isEmpty && urlc.path.isEmpty
                            {
                                if host.hasPrefix("/") {
                                    urlc.path = host
                                }
                                else {
                                    urlc.path = "/\(host)"
                                }
                            }

                            urlc.host = Config.baseDomain

                            if let url = urlc.url {
                                log.info("Opening haip URL: \(url)")

                                model.openUrl(url)
                            }
                            else {
                                log.warning("Could not build URL in our own domain \"\(Config.baseDomain)\" from haip URL: \(url) -> \(urlc)")
                            }
                        }
                        else if url.host == Config.baseDomain {
                            log.info("Opening URL in our own domain \"\(Config.baseDomain)\": \(url)")

                            model.openUrl(url)
                        }
                        else {
                            log.warning("App called with URL which neither has the `haip` scheme nor is in our own domain: \(url)")
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
