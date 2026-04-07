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
    case list
    case format
    case size
    case color
    case open
    case name
    case verbose
    case scanner
    case resolution
    case browseSecs = "browsesecs"
    case exactName = "exactname"
    case rotate

    var type: ConfigOptionType {
        switch self {
        case .name, .scanner, .resolution, .browseSecs, .rotate,
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
        case .browseSecs: "10"
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
        case .list:
            "List all available scanners, then exit."
        case .format:
            "Output format: pdf (default), jpeg, tiff, png"
        case .size:
            "Page size: a4 (default), letter, legal"
        case .color:
            "Color mode: color (default), mono"
        case .open:
            "Open the scanned image when done."
        case .name:
            "Specify a custom name for the output file (without extension)"
        case .verbose:
            "Provide verbose logging."
        case .scanner:
            "Specify which scanner to use (use -list to list available scanners)."
        case .resolution:
            "Specify minimum resolution at which to scan (in dpi)"
        case .browseSecs:
            "Specify how long to wait when searching for scanners (in seconds)"
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
            Self.exitWithError(error)
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

    // MARK: - Private

    private static let defaultConfigFilePath = "\(NSHomeDirectory())/.config/scanner/scanner.conf"

    static func parse(
        arguments: [String],
        into config: inout [ConfigOption: ConfigValue]
    ) throws {
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]

            if arg == "-help" || arg == "--help" || arg == "-h" {
                self.printHelp()
                exit(0)
            } else if arg.hasPrefix("-") {
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

    private static func exitWithError(_ error: Error) -> Never {
        let message: String = switch error {
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
        fputs("Error: \(message)\n", stderr)
        fputs("Run 'scanner -h' for usage information.\n", stderr)
        exit(1)
    }

    private static func printHelp() {
        print("Usage: scanner [options]")
        print("")
        print("Scan documents from a flatbed or document feeder and save to the current directory.")
        print("Config file: ~/.config/scanner/scanner.conf")
        print("")

        self.printSection("Scanning", options: [
            (.input, "Scan source [feeder, flatbed] (default: feeder)"),
            (.duplex, "Scan both sides of each page"),
            (.batch, "Pause after each page to allow additional pages"),
        ])

        self.printSection("Output Format", options: [
            (.format, "File format [pdf, jpeg, tiff, png] (default: pdf)"),
        ])

        self.printSection("Page Size", options: [
            (.size, "Page size [a4, letter, legal] (default: a4)"),
        ])

        self.printSection("Image", options: [
            (.color, "Color mode [color, mono] (default: color)"),
            (.resolution, "Minimum resolution in dpi"),
            (.rotate, "Rotate scanned images by degrees"),
        ])

        self.printSection("Output", options: [
            (.name, "Custom filename (without extension)"),
            (.open, "Open the file after scanning"),
        ])

        self.printSection("Scanner Selection", options: [
            (.list, "List available scanners and exit"),
            (.scanner, "Use a specific scanner by name (substring match)"),
            (.exactName, "Require exact name match with -scanner"),
            (.browseSecs, "Scanner discovery timeout in seconds"),
        ])

        self.printSection("General", options: [
            (.verbose, "Enable verbose logging"),
        ])

        print("Examples:")
        print("  scanner                              Scan to PDF in current directory")
        print("  scanner -duplex                      Scan both sides")
        print("  scanner -name invoice -format jpeg   Scan to invoice.jpg")
        print("  scanner -input flatbed -color mono   Scan from flatbed in black and white")
        print("  scanner -list                        Show available scanners")
        print("  scanner -size legal                  Scan a legal size page")
    }

    private static func printSection(_ title: String, options: [(ConfigOption, String)]) {
        print("\(title):")
        for (option, description) in options {
            let flag = "-\(option.rawValue)"
            var line = "  \(flag.padding(toLength: 20, withPad: " ", startingAt: 0))\(description)"
            if let defaultValue = option.defaultValue, option.validValues == nil {
                line += " (default: \(defaultValue))"
            }
            print(line)
        }
        print("")
    }
}
