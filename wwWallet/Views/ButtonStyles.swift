//
//  ButtonStyles.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-18.
//

import SwiftUI

public struct BasicButtonStyle: ButtonStyle {
    
    let background = Color.blue
    let foreground = Color.white
    
    public func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(8)
                .foregroundStyle(configuration.isPressed ? foreground.opacity(0.5) : foreground)
                .background(configuration.isPressed ? background.opacity(0.7) : background)
                .clipShape(.rect(cornerRadius: 8))
    }
}

public extension ButtonStyle where Self == BasicButtonStyle {
    static var basicButton: Self {
        return .init()
    }
}
