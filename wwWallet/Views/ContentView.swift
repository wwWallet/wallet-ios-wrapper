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
    private var topBgColor = Color(red: 0, green: 65 / 255, blue: 149 / 255)

    @State
    private var buttonBgColor = Color(red: 0, green: 52 / 255, blue: 118 / 255)

    @State
    private var bottomBgColor = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)

    /**
     We need this here, so view gets updated when it changes.
     */
    @AppStorage("environment")
    private var baseDomainIdx = 1


    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .background(topBgColor)

            HStack {
                Image("wallet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .padding(.leading, 16)
                    .padding(.bottom, 8)

                VStack {
                    Text("Current wallet")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.caption)

                    // At least once, we need `baseDomainIdx` referenced, so view gets updated when it changes.
                    Text(baseDomainIdx < Config.baseDomains.count ? Config.baseDomains[baseDomainIdx] : Config.baseDomain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 8)

                Spacer()

                Menu {
                    ForEach(Array(Config.baseDomains.enumerated()), id: \.offset) { idx, name in
                        Button(name) {
                            baseDomainIdx = idx
                        }
                    }
                } label: {
                    Label("Switch wallet", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                }
                .background(buttonBgColor)
                .clipShape(.rect(cornerRadius: 8))
                .buttonStyle(.basicButton)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
            .background(topBgColor)
            .clipShape(.rect(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 0))


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
            }

            HStack {
                Spacer()
            }
            .background(bottomBgColor)
        }
        .onAppear {
            Task {
                // Point the user at the passkeys auto-fill feature.
                await ASSettingsHelper.requestToTurnOnCredentialProviderExtension()
            }
        }
        .onChange(of: baseDomainIdx, initial: true) {
            Task {
                do {
                    let colors = try await ColorFinder.go()

                    if let top = colors.top {
                        topBgColor = top
                    }

                    if let button = colors.button {
                        buttonBgColor = button
                    }

                    if let bottom = colors.bottom {
                        bottomBgColor = bottom
                    }
                }
                catch {
                    let log = Logger(with: self)
                    log.error("\(error)")
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
