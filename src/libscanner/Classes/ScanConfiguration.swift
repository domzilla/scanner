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
    case duplex
    case batch
    case list
    case flatbed
    case jpeg
    case tiff
    case png
    case legal
    case letter
    case a4
    case mono
    case open
    case dir
    case name
    case verbose
    case scanner
    case resolution
    case browseSecs = "browsesecs"
    case exactName = "exactname"
    case ocr
    case rotate
    case summarize
    case autoname

    var synonyms: [String] {
        switch self {
        case .duplex: ["dup"]
        case .flatbed: ["fb"]
        case .jpeg: ["jpg"]
        case .tiff: ["tif"]
        case .mono: ["bw"]
        case .dir: ["folder"]
        case .verbose: ["v"]
        case .scanner: ["s"]
        case .resolution: ["res", "minResolution"]
        case .browseSecs: ["time", "t"]
        case .exactName: ["exact"]
        case .summarize: ["summary"]
        default: []
        }
    }

    var type: ConfigOptionType {
        switch self {
        case .dir, .name, .scanner, .resolution, .browseSecs, .rotate:
            .string
        default:
            .flag
        }
    }

    var defaultValue: String? {
        switch self {
        case .dir: "\(NSHomeDirectory())/Documents/Archive"
        case .resolution: "150"
        case .browseSecs: "10"
        case .rotate: "0"
        default: nil
        }
    }

    var description: String {
        switch self {
        case .duplex:
            "Duplex (two-sided) scanning mode, for scanners that support it."
        case .batch:
            "scanline will pause after each page, allowing you to continue to scan additional pages until you say you're done."
        case .list:
            "List all available scanners, then exit."
        case .flatbed:
            "Scan from the scanner's flatbed (default is paper feeder)"
        case .jpeg:
            "Scan to a JPEG file (default is PDF)"
        case .tiff:
            "Scan to a TIFF file (default is PDF)"
        case .png:
            "Scan to a PNG file (default is PDF)"
        case .legal:
            "Scan a legal size page"
        case .letter:
            "Scan a letter size page"
        case .a4:
            "Scan an A4 size page"
        case .mono:
            "Scan in monochrome (black and white)"
        case .open:
            "Open the scanned image when done."
        case .dir:
            "Specify a directory where the files should go."
        case .name:
            "Specify a custom name for the output file."
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
        case .ocr:
            "Converts the scanned image(s) to text and outputs to stdout"
        case .rotate:
            "Specify degrees to rotate the scanned images"
        case .summarize:
            "Use on-device OCR and Apple Intelligence to output a .summary.txt file with a brief description of the document's text."
        case .autoname:
            "Use on-device OCR and Apple Intelligence to create a concise and accurate name for the output file."
        }
    }

    static func from(key: String) -> ConfigOption? {
        if let option = ConfigOption(rawValue: key) {
            return option
        }
        for option in ConfigOption.allCases {
            if option.synonyms.contains(key) {
                return option
            }
        }
        return nil
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

// MARK: - ScanConfiguration

final class ScanConfiguration: Sendable {
    let config: [ConfigOption: ConfigValue]
    let tags: [String]

    init(arguments: [String] = [], configFilePath: String? = nil) {
        var config: [ConfigOption: ConfigValue] = [:]
        var tags: [String] = []

        // 1. Load defaults
        for option in ConfigOption.allCases {
            if let defaultValue = option.defaultValue {
                config[option] = .string(defaultValue)
            }
        }

        // 2. Load config file
        let filePath = configFilePath ?? ScanConfiguration.defaultConfigFilePath
        if
            FileManager.default.isReadableFile(atPath: filePath),
            let contents = try? String(contentsOfFile: filePath, encoding: .utf8)
        {
            let fileArgs = contents.components(separatedBy: "\n")
            ScanConfiguration.parse(arguments: fileArgs, into: &config, tags: &tags)
        }

        // 3. Load CLI arguments (override everything)
        ScanConfiguration.parse(arguments: arguments, into: &config, tags: &tags)

        self.config = config
        self.tags = tags
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

    private static let defaultConfigFilePath = "\(NSHomeDirectory())/.scanline.conf"

    private static func parse(
        arguments: [String],
        into config: inout [ConfigOption: ConfigValue],
        tags: inout [String]
    ) {
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]

            if arg == "-help" || arg == "--help" {
                self.printHelp()
                exit(1)
            } else if arg.hasPrefix("-") {
                let key = String(arg.dropFirst())
                if let option = ConfigOption.from(key: key) {
                    switch option.type {
                    case .string:
                        if i + 1 < arguments.count {
                            i += 1
                            config[option] = .string(arguments[i])
                        } else {
                            self.log("WARNING: No value provided for option '\(arg)'")
                        }
                    case .flag:
                        config[option] = .flag(true)
                    }
                } else {
                    self.log("WARNING: Unknown option '\(arg)' will be ignored")
                }
            } else if !arg.isEmpty {
                tags.append(arg)
            }

            i += 1
        }
    }

    private static func log(_ message: String) {
        print(message)
    }

    private static func printHelp() {
        print("Usage: scanner [-option] [-option] [tag] [tag] [tag]...")
        print("")

        for option in ConfigOption.allCases {
            print("-\(option.rawValue):")
            print("Purpose: \(option.description)")
            if let defaultValue = option.defaultValue {
                print("Default: \(defaultValue)")
            }
            print("")
        }

        let defaultDir = ConfigOption.dir.defaultValue ?? "~/Documents/Archive"
        print("")
        print("Examples:")
        print("")
        print("scanner -duplex taxes")
        print("   ^-- Scan 2-sided and place in \(defaultDir)/taxes/")
        print("scanner bills dental")
        print("   ^-- Scan and place in \(defaultDir)/bills/ with alias in \(defaultDir)/dental/")
    }
}
