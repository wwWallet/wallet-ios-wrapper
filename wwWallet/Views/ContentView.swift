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

    @Environment(\.scenePhase) var scenePhase

    @State
    private var buttonBgColor = Color(red: 0, green: 52 / 255, blue: 118 / 255)

    @State
    private var bgColor = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)

    /**
     We need this here, so view gets updated when it changes.
     */
    @AppStorage("environment")
    private var baseDomainIdx = 1


    var body: some View {
        ZStack {
            Color(red: 17/255, green: 25/255, blue: 40/255)
            VStack {
                WebView(
                    url: URL(string: "https://\(Config.baseDomain)")!,
                    model: model)
                    .onOpenURL { url in
                        let log = Logger(with: self)

                        if url.scheme == "haip" || url.scheme == "openid4vp",
                           var urlc = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        {
                            // haip URLs should basically consist of URL query components.
                            // Rewrite scheme, host and path to what is needed for our web frontend.

                            urlc.scheme = "https"
                            urlc.host = Config.baseDomain
                            urlc.path = "/cb"

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

#if ALLOW_DOMAIN_SWITCHING
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    Menu {
                        ForEach(Array(Config.baseDomains.enumerated()), id: \.offset) { idx, name in
                            Button(name) {
                                baseDomainIdx = idx
                            }
                        }
                    } label: {
                        Label(baseDomainIdx < Config.baseDomains.count ? Config.baseDomains[baseDomainIdx] : Config.baseDomain, systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    }
                    .background(buttonBgColor)
                    .clipShape(.rect(cornerRadius: 8))
                    .buttonStyle(.basicButton)
                    .padding(.trailing, 24)
                    .padding(.bottom, 8)
                }
            }
            .padding(.top, 16)
#endif
        }
#if ALLOW_DOMAIN_SWITCHING
        .ignoresSafeArea(edges: .bottom)
#endif
        .background(bgColor)
        .onAppear {
            Task {
                // Point the user at the passkeys auto-fill feature.
                await ASSettingsHelper.requestToTurnOnCredentialProviderExtension()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
