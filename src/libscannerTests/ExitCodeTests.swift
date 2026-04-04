//
//  ExitCodeTests.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 04.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import libscanner

struct ExitCodeTests {
    @Test
    func successIsZero() {
        #expect(ExitCode.success.rawValue == 0)
    }

    @Test
    func failureIsOne() {
        #expect(ExitCode.failure.rawValue == 1)
    }
}
