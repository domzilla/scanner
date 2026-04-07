//
//  Logger.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

enum Logger {
    /// Configuration reference for verbose logging.
    /// Must be set once at startup before any logging calls.
    nonisolated(unsafe) static var configuration: ScanConfiguration?

    /// Verbose logging — prints only when `-verbose` flag is set.
    /// Works in both debug and release builds.
    static func verbose(_ message: String) {
        guard let configuration = self.configuration, configuration.flag(.verbose) else { return }
        print(message)
    }

    /// Debug logging — only active in DEBUG builds.
    static func debug(_ message: String, function: String = #function, line: Int = #line) {
        #if DEBUG
        FileHandle.standardError.write(Data("[DEBUG] \(function):\(line) \(message)\n".utf8))
        #endif
    }

    /// Error logging — only active in DEBUG builds.
    static func error(_ error: Error?, function: String = #function, line: Int = #line) {
        #if DEBUG
        guard let error else { return }
        FileHandle.standardError.write(Data("[ERROR] \(function):\(line) \(error.localizedDescription)\n".utf8))
        #endif
    }
}
