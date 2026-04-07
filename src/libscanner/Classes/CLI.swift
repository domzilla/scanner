//
//  CLI.swift
//  scanner
//
//  Created by Dominic Rodemer on 07.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

// MARK: - CLI

enum CLI {
    /// Whether the `list` subcommand was invoked.
    private(set) nonisolated(unsafe) static var listMode = false

    /// Scanner discovery timeout in seconds.
    private(set) nonisolated(unsafe) static var timeout: Double = 10.0

    static func parseArguments(_ arguments: [String]) -> ScanConfiguration {
        var args = arguments

        // Handle subcommands first (before help, so `list -h` works)
        if let first = args.first, !first.hasPrefix("-"), !first.isEmpty {
            if first == "list" {
                self.listMode = true
                args.removeFirst()
            } else {
                self.exitWithError("Unknown command '\(first)'")
            }
        }

        // Handle help
        if args.contains("--help") || args.contains("-h") {
            if self.listMode {
                self.printListHelp()
            } else {
                self.printHelp()
            }
            exit(0)
        }

        // Extract --timeout / -t before passing to ScanConfiguration
        if let index = args.firstIndex(of: "--timeout") ?? args.firstIndex(of: "-t") {
            if index + 1 < args.count {
                let value = args[index + 1]
                guard let parsed = Double(value) else {
                    self.exitWithError("Invalid value for '--timeout': '\(value)'")
                }
                self.timeout = parsed
                args.removeSubrange(index...index + 1)
            } else {
                self.exitWithError("No value provided for option '--timeout'")
            }
        }

        return ScanConfiguration(arguments: args)
    }

    static func exitWithError(_ message: String) -> Never {
        fputs("Error: \(message)\n", stderr)
        fputs("Run 'scanner -h' for usage information.\n", stderr)
        exit(1)
    }

    // MARK: - Help

    private static func printHelp() {
        print("Usage: scanner [options]")
        print("       scanner list [--timeout N]")
        print("")
        print("Scan documents from a flatbed or document feeder and save to the current directory.")
        print("Config file: ~/.config/scanner/scanner.conf")
        print("")

        print("Commands:")
        print("  list                  List available scanners and exit (see 'scanner list -h')")
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
        ])

        self.printSection("Scanner", options: [
            (.scanner, "Use a specific scanner by name (substring match)"),
            (.exactName, "Require exact name match with --scanner"),
        ])

        self.printSection("General", options: [
            (.verbose, "Enable verbose logging"),
        ])

        print("Examples:")
        print("  scanner                                Scan to PDF in current directory")
        print("  scanner --duplex                       Scan both sides")
        print("  scanner --name invoice --format jpeg   Scan to invoice.jpg")
        print("  scanner --input flatbed --color mono   Scan from flatbed in black and white")
        print("  scanner list                           Show available scanners")
        print("  scanner --size legal                   Scan a legal size page")
    }

    private static func printListHelp() {
        print("Usage: scanner list [options]")
        print("")
        print("List all available scanners and exit.")
        print("")
        print("Options:")
        print("  -t, --timeout         Scanner discovery timeout in seconds (default: 10)")
        print("")
        print("Examples:")
        print("  scanner list                         List scanners")
        print("  scanner list --timeout 15            Search for 15 seconds")
    }

    private static func printSection(_ title: String, options: [(ConfigOption, String)]) {
        print("\(title):")
        for (option, description) in options {
            let longFlag = "--\(option.rawValue)"
            let flag = if let short = option.shortFlag {
                "-\(short), \(longFlag)"
            } else {
                "    \(longFlag)"
            }
            var line = "  \(flag.padding(toLength: 22, withPad: " ", startingAt: 0))\(description)"
            if let defaultValue = option.defaultValue, option.validValues == nil {
                line += " (default: \(defaultValue))"
            }
            print(line)
        }
        print("")
    }
}
