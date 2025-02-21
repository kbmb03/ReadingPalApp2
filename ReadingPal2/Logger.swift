//
//  Logger.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 2/21/25.
//

import Foundation

struct Logger {
    static let isDebug = false
    static func log(_ message: String) {
        if isDebug {
            print(message)
        }
    }
}
