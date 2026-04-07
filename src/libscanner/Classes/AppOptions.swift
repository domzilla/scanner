//
//  AppOptions.swift
//  scanner
//
//  Created by Dominic Rodemer on 07.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

// MARK: - AppOptions

public struct AppOptions: Sendable {
    public enum Mode: Sendable {
        case scan
        case list
    }

    public let mode: Mode
    public let timeout: Double

    public init(mode: Mode = .scan, timeout: Double = 10.0) {
        self.mode = mode
        self.timeout = timeout
    }
}
