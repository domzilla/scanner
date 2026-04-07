//
//  ScanConfiguration.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

// MARK: - ConfigOption

enum ConfigOption: String, CaseIterable, Sendable {
    case input
    case duplex
    case batch
    case format
    case size
    case color
    case name
    case verbose
    case scanner
    case resolution
    case exactName = "exactname"
    case rotate

    var type: ConfigOptionType {
        switch self {
        case .name, .scanner, .resolution, .rotate,
             .input, .format, .size, .color:
            .string
        default:
            .flag
        }
    }

    var defaultValue: String? {
        switch self {
        case .input: "feeder"
        case .format: "pdf"
        case .size: "a4"
        case .color: "color"
        case .resolution: "150"
        case .rotate: "0"
        default: nil
        }
    }

    /// Valid values for enum-type options.
    var validValues: [String: String]? {
        switch self {
        case .input:
            ["feeder": "feeder", "flatbed": "flatbed"]
        case .format:
            ["pdf": "pdf", "jpeg": "jpeg", "tiff": "tiff", "png": "png"]
        case .size:
            ["a4": "a4", "letter": "letter", "legal": "legal"]
        case .color:
            ["color": "color", "mono": "mono"]
        default:
            nil
        }
    }

    var description: String {
        switch self {
        case .input:
            "Scan source: feeder (default), flatbed"
        case .duplex:
            "Duplex (two-sided) scanning mode, for scanners that support it."
        case .batch:
            "scanner will pause after each page, allowing you to continue to scan additional pages until you say you're done."
        case .format:
            "Output format: pdf (default), jpeg, tiff, png"
        case .size:
            "Page size: a4 (default), letter, legal"
        case .color:
            "Color mode: color (default), mono"
        case .name:
            "Specify a custom name for the output file (without extension)"
        case .verbose:
            "Provide verbose logging."
        case .scanner:
            "Specify which scanner to use."
        case .resolution:
            "Specify minimum resolution at which to scan (in dpi)"
        case .exactName:
            "When specified, only the scanner with the exact name specified will be used (no fuzzy matching)"
        case .rotate:
            "Specify degrees to rotate the scanned images"
        }
    }

    static func from(key: String) -> ConfigOption? {
        ConfigOption(rawValue: key)
    }
}

enum ConfigOptionType: Sendable {
    case flag
    case string
}

// MARK: - ConfigValue

enum ConfigValue: Sendable {
    case flag(Bool)
    case string(String)
}

// MARK: - ConfigError

enum ConfigError: Error, Equatable {
    case unknownOption(String)
    case unknownArgument(String)
    case missingValue(String)
    case invalidValue(String, String)
}

// MARK: - ScanConfiguration

final class ScanConfiguration: Sendable {
    let config: [ConfigOption: ConfigValue]

    init(arguments: [String] = [], configFilePath: String? = nil) {
        var config: [ConfigOption: ConfigValue] = [:]

        // 1. Load defaults
        for option in ConfigOption.allCases {
            if let defaultValue = option.defaultValue {
                config[option] = .string(defaultValue)
            }
        }

        // 2. Load config file (errors in config file are non-fatal)
        let filePath = configFilePath ?? ScanConfiguration.defaultConfigFilePath
        if
            FileManager.default.isReadableFile(atPath: filePath),
            let contents = try? String(contentsOfFile: filePath, encoding: .utf8)
        {
            let fileArgs = contents.components(separatedBy: "\n")
            try? ScanConfiguration.parse(arguments: fileArgs, into: &config)
        }

        // 3. Load CLI arguments (errors are fatal)
        do {
            try ScanConfiguration.parse(arguments: arguments, into: &config)
        } catch {
            CLI.exitWithError(Self.errorMessage(for: error))
        }

        self.config = config
    }

    // MARK: - Convenience Accessors

    func flag(_ option: ConfigOption) -> Bool {
        if case .flag(true) = self.config[option] {
            return true
        }
        return false
    }

    func string(_ option: ConfigOption) -> String? {
        if case let .string(value) = self.config[option] {
            return value
        }
        return nil
    }

    // MARK: - Parsing

    private static let defaultConfigFilePath = "\(NSHomeDirectory())/.config/scanner/scanner.conf"

    static func parse(
        arguments: [String],
        into config: inout [ConfigOption: ConfigValue]
    ) throws {
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]

            if arg.hasPrefix("-") {
                let key = String(arg.dropFirst())
                if let option = ConfigOption.from(key: key) {
                    switch option.type {
                    case .string:
                        if i + 1 < arguments.count {
                            i += 1
                            let rawValue = arguments[i]
                            if let validValues = option.validValues {
                                guard let canonical = validValues[rawValue] else {
                                    let allowed = Set(validValues.values).sorted().joined(separator: ", ")
                                    throw ConfigError.invalidValue(arg, allowed)
                                }
                                config[option] = .string(canonical)
                            } else {
                                config[option] = .string(rawValue)
                            }
                        } else {
                            throw ConfigError.missingValue(arg)
                        }
                    case .flag:
                        config[option] = .flag(true)
                    }
                } else {
                    throw ConfigError.unknownOption(arg)
                }
            } else if !arg.isEmpty {
                throw ConfigError.unknownArgument(arg)
            }

            i += 1
        }
    }

    static func errorMessage(for error: Error) -> String {
        switch error {
        case let ConfigError.unknownOption(arg):
            "Unknown option '\(arg)'"
        case let ConfigError.unknownArgument(arg):
            "Unknown argument '\(arg)'"
        case let ConfigError.missingValue(arg):
            "No value provided for option '\(arg)'"
        case let ConfigError.invalidValue(arg, allowed):
            "Invalid value for '\(arg)'. Valid values: \(allowed)"
        default:
            error.localizedDescription
        }
    }
}
