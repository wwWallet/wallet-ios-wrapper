//
//  Logger+Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 21.04.25.
//

import Foundation
import OSLog

public extension Logger {

    /**
     Creates a logger which uses the ID of the bundle to which the class belongs as the `subsystem` and the classes' name as the `category`.

     - parameter class: The class to find the bundle ID with and to use as the `category`.
     */
    init(for class: AnyClass) {
        self.init(for: `class`, category: String(describing: `class`))
    }

    /**
     Creates a logger which uses the ID of the bundle to which the class belongs as the `subsystem`.

     - parameter class: The class to find the bundle ID with to use as the `subsystem`.
     - parameter category: The string that the system uses to categorize emitted signposts.
     */
    init(for class: AnyClass, category: String) {
        self.init(subsystem: Bundle(for: `class`).bundleIdentifier ?? String(describing: `class`), category: category)
    }

    /**
     Creates a logger which uses the name of the subject as subsystem and category.

     - parameter subject: The subject to use its name as the subsystem and category.
     */
    init<Subject>(with subject: Subject) {
        self.init(subsystem: String(describing: subject), category: String(describing: subject))
    }
}
