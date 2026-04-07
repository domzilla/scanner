//
//  LoggerTests.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 04.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import libscanner

struct LoggerTests {
    @Test
    func verboseWithNilConfiguration() {
        Logger.configuration = nil
        Logger.verbose("test message")
    }

    @Test
    func verboseWithoutVerboseFlag() throws {
        Logger.configuration = try makeConfig([])
        Logger.verbose("test message")
    }

    @Test
    func verboseWithVerboseFlag() throws {
        Logger.configuration = try makeConfig(["--verbose"])
        Logger.verbose("test message")
    }

    @Test
    func debugDoesNotCrash() {
        Logger.debug("test debug message")
    }

    @Test
    func errorWithNilDoesNotCrash() {
        Logger.error(nil)
    }

    @Test
    func errorWithActualError() {
        let error = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "test error"])
        Logger.error(error)
    }
}
