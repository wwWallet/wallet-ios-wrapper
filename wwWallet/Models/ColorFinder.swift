//
//  ColorFinder.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 07.11.25.
//

import SwiftUI
import SwiftCSSParser
import OSLog

class ColorFinder {

    enum Errors: Error {

        case invalidUrl
        case no200Response
        case bodyUnreadable
        case stylesheetNotFound
    }

    class func go() async throws -> (top: Color?, bottom: Color?) {
        guard let url = URL(string: "https://\(Config.baseDomain)") else {
            throw Errors.invalidUrl
        }

        let html = try await load(url)

        let stylesheetRegex = /<link rel="stylesheet".*href="(.*)">/
            .ignoresCase()

        guard let result = try stylesheetRegex.firstMatch(in: html) else {
            throw Errors.stylesheetNotFound
        }

        let css = try await load(url.appending(path: result.1))

        let statements = try Stylesheet.parseStatements(from: css)

        let log = Logger(with: self)

        var top: Color? = nil

        if let color1 = find(".dark\\:bg-primary-hover:is(.dark *)", "background-color", in: statements) {
            log.info("Top color: \(color1)")

            top = try getColor(from: color1)
        }

        guard let color2 = find(".dark\\:bg-gray-900:is(.dark *)", "background-color", in: statements) else {
            return (top, nil)
        }

        log.info("Bottom color: \(color2)")

        let bottom = try getColor(from: color2) 

        return (top, bottom)
    }

    private class func load(_ url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: .init(url: url))

        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200
        else {
            throw Errors.no200Response
        }

        guard data.count > 0,
              let content = String(data: data, encoding: .utf8)
        else {
            throw Errors.bodyUnreadable
        }

        return content
    }

    private class func find(_ selector: String, _ property: String, in statements: [Statement]) -> String? {
        for statement in statements {
            switch statement {
            case .ruleSet(let ruleSet):
                if ruleSet.selector == selector {
                    for declaration in ruleSet.declarations where declaration.property == property {
                        return declaration.value
                    }
                }

            default:
                break
            }
        }

        return nil
    }

    private static let rgbColorRegex = /rgb\((\d+)\s+(\d+)\s+(\d+)/
        .ignoresCase()

    private static let hexColorRegex = /#([\da-f]{3,8})/
        .ignoresCase()

    private class func getColor(from value: String) throws -> Color? {
        if let result = try rgbColorRegex.firstMatch(in: value),
              let red = Double(result.1),
              let green = Double(result.2),
              let blue = Double(result.3)
        {
            return Color(red: red / 255, green: green / 255, blue: blue / 255)
        }

        if let result = try hexColorRegex.firstMatch(in: value) {
            return Color(hex: result.1)
        }


        return nil
    }
}
