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

    var body: some View {
        ZStack {
            Color(red: 17/255, green: 25/255, blue: 40/255)
            VStack {
                WebView(
                    url: URL(string: "https://\(Config.baseDomain)")!,
                    model: model)
                    .onOpenURL { url in
                        let log = Logger(with: self)

                        if url.scheme == "haip",
                           var urlc = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        {
                            // haip URLs should basically consist of URL querie components.
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
        }
        .onAppear {
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
