//
//  CLI.swift
//  scanner
//
//  Created by Dominic Rodemer on 07.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import libscanner

// MARK: - CLI

enum CLI {
    static func parseArguments(_ arguments: [String]) -> (AppOptions, ScanConfiguration) {
        var args = arguments
        var mode: AppOptions.Mode = .scan
        var timeout = 10.0

        // Handle subcommands first (before help, so `list -h` works)
        if let first = args.first, !first.hasPrefix("-"), !first.isEmpty {
            if first == "list" {
                mode = .list
                args.removeFirst()
            } else {
                self.exitWithError("Unknown command '\(first)'")
            }
        }

        // Handle --version
        if args.contains("--version") {
            self.printVersionAndExit()
        }

        // Handle help
        if args.contains("--help") || args.contains("-h") {
            if mode == .list {
                self.handleCommandHelp("list")
            } else {
                self.handleMainHelp()
            }
        }

        // Extract --timeout / -t before passing to ScanConfiguration
        if let index = args.firstIndex(of: "--timeout") ?? args.firstIndex(of: "-t") {
            if index + 1 < args.count {
                let value = args[index + 1]
                guard let parsed = Double(value) else {
                    self.exitWithError("Invalid value for '--timeout': '\(value)'")
                }
                timeout = parsed
                args.removeSubrange(index...index + 1)
            } else {
                self.exitWithError("No value provided for option '--timeout'")
            }
        }

        let options = AppOptions(mode: mode, timeout: timeout)

        do {
            let configuration = try ScanConfiguration(arguments: args)
            return (options, configuration)
        } catch {
            self.exitWithError(ScanConfiguration.errorMessage(for: error))
        }
    }

    private static func printVersionAndExit() -> Never {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let data = Data("\(version)\n".utf8)
        FileHandle.standardOutput.write(data)
        exit(0)
    }

    static func exitWithError(_ message: String) -> Never {
        fputs("Error: \(message)\n", stderr)
        fputs("Run 'scanner -h' for usage information.\n", stderr)
        exit(1)
    }

    // MARK: - Help

    private static func handleMainHelp() -> Never {
        let text = HelpFormatter.formatMainHelp(
            title: "scanner - Document Scanning CLI",
            usage: [
                "scanner [options]",
                "scanner list [options]",
            ],
            description: "Scan documents from a flatbed or document feeder and save to the current directory.",
            configFile: "~/.config/scanner/scanner.conf",
            commands: [
                HelpCommandDTO(
                    command: "scanner list",
                    description: "List available scanners and exit"
                ),
            ],
            optionGroups: [
                OptionGroupDTO(title: "Scanning", parameters: [
                    ParameterInfoDTO(
                        name: "--input", shortFlag: "-i", type: "source", required: false,
                        description: "Scan source [feeder, flatbed] (default: feeder)"
                    ),
                    ParameterInfoDTO(
                        name: "--duplex", shortFlag: "-d", type: "flag", required: false,
                        description: "Scan both sides of each page"
                    ),
                    ParameterInfoDTO(
                        name: "--batch", shortFlag: "-b", type: "flag", required: false,
                        description: "Pause after each page to allow additional pages"
                    ),
                ]),
                OptionGroupDTO(title: "Output Format", parameters: [
                    ParameterInfoDTO(
                        name: "--format", shortFlag: "-f", type: "format", required: false,
                        description: "File format [pdf, jpeg, tiff, png] (default: pdf)"
                    ),
                    ParameterInfoDTO(
                        name: "--no-mrc", shortFlag: nil, type: "flag", required: false,
                        description: "Disable Mixed Raster Content output (PDF only). PDF output is MRC by default: crisp 1-bit text layer over a compressed color background."
                    ),
                    ParameterInfoDTO(
                        name: "--mrc-resolution", shortFlag: nil, type: "dpi", required: false,
                        description: "Text-layer resolution in dpi for MRC PDF output (default: 400)"
                    ),
                    ParameterInfoDTO(
                        name: "--mrc-jpeg-quality", shortFlag: nil, type: "0-100", required: false,
                        description: "JPEG quality for the MRC background layer (default: 20). Safe to run low because the 1-bit text mask preserves glyph sharpness."
                    ),
                    ParameterInfoDTO(
                        name: "--jpeg-quality", shortFlag: nil, type: "0-100", required: false,
                        description: "JPEG quality for the no-MRC PDF background (default: 60, used with --no-mrc). Kept higher than --mrc-jpeg-quality because text is JPEG-encoded directly in this mode."
                    ),
                ]),
                OptionGroupDTO(title: "Page Size", parameters: [
                    ParameterInfoDTO(
                        name: "--size", shortFlag: "-s", type: "size", required: false,
                        description: "Page size [a4, letter, legal] (default: a4)"
                    ),
                ]),
                OptionGroupDTO(title: "Image", parameters: [
                    ParameterInfoDTO(
                        name: "--color", shortFlag: "-c", type: "mode", required: false,
                        description: "Color mode [color, mono] (default: color)"
                    ),
                    ParameterInfoDTO(
                        name: "--resolution", shortFlag: "-r", type: "dpi", required: false,
                        description: "Minimum resolution in dpi (default: 150)"
                    ),
                    ParameterInfoDTO(
                        name: "--rotate", shortFlag: nil, type: "degrees", required: false,
                        description: "Rotate scanned images by degrees (default: 0)"
                    ),
                ]),
                OptionGroupDTO(title: "Output", parameters: [
                    ParameterInfoDTO(
                        name: "--name", shortFlag: "-n", type: "name", required: false,
                        description: "Custom filename (without extension)"
                    ),
                ]),
                OptionGroupDTO(title: "Scanner", parameters: [
                    ParameterInfoDTO(
                        name: "--scanner", shortFlag: nil, type: "name", required: false,
                        description: "Use a specific scanner by name (substring match)"
                    ),
                    ParameterInfoDTO(
                        name: "--exactname", shortFlag: "-e", type: "flag", required: false,
                        description: "Require exact name match with --scanner"
                    ),
                ]),
                OptionGroupDTO(title: "General", parameters: [
                    ParameterInfoDTO(
                        name: "--verbose", shortFlag: nil, type: "flag", required: false,
                        description: "Enable verbose logging"
                    ),
                    ParameterInfoDTO(
                        name: "--version", shortFlag: nil, type: "flag", required: false,
                        description: "Print version and exit"
                    ),
                ]),
                OptionGroupDTO(title: "Debug", parameters: [
                    ParameterInfoDTO(
                        name: "--debug-input", shortFlag: nil, type: "path", required: false,
                        description: "Development/testing only. Skip the hardware scanner and feed the given image file or directory of images into the normal output pipeline (rotate, format, PDF assembly, MRC). A directory is expanded to its image files (jpg/jpeg/png/tif/tiff) sorted by filename. Inputs are copied to a temp dir first so --rotate won't mutate your originals."
                    ),
                ]),
            ],
            examples: [
                ExampleDTO(command: "scanner", description: "Scan to PDF in current directory"),
                ExampleDTO(command: "scanner --duplex", description: "Scan both sides"),
                ExampleDTO(command: "scanner --name invoice --format jpeg", description: "Scan to invoice.jpg"),
                ExampleDTO(
                    command: "scanner --input flatbed --color mono",
                    description: "Scan from flatbed in black and white"
                ),
                ExampleDTO(command: "scanner list", description: "Show available scanners"),
                ExampleDTO(command: "scanner --size legal", description: "Scan a legal size page"),
                ExampleDTO(
                    command: "scanner --no-mrc",
                    description: "Scan to a plain image-per-page PDF (disable MRC)"
                ),
                ExampleDTO(
                    command: "scanner --debug-input /tmp/pages",
                    description: "Run the pipeline against existing images (skip scanner)"
                ),
            ]
        )
        HelpFormatter.printAndExit(text)
    }

    private static func handleCommandHelp(_ name: String) -> Never {
        let commands = self.commandList()
        if let cmd = commands.first(where: { self.matchesCommand($0.command, name: name) }) {
            let text = HelpFormatter.formatCommandHelp(cmd)
            HelpFormatter.printAndExit(text)
        }
        self.exitWithError("Unknown command '\(name)'")
    }

    private static func matchesCommand(_ command: String, name: String) -> Bool {
        let normalized = command
            .replacingOccurrences(of: "scanner ", with: "")
            .components(separatedBy: " ")
            .filter { !$0.hasPrefix("<") && !$0.hasPrefix("[") }
            .joined(separator: " ")
        return normalized == name
    }

    // MARK: - Command List

    private static func commandList() -> [CommandInfoDTO] {
        [
            CommandInfoDTO(
                command: "scanner list",
                description: "List all available scanners and exit.",
                parameters: [
                    ParameterInfoDTO(
                        name: "--timeout",
                        shortFlag: "-t",
                        type: "seconds",
                        required: false,
                        description: "Scanner discovery timeout in seconds (default: 10)"
                    ),
                ],
                output: nil,
                examples: [
                    ExampleDTO(command: "scanner list", description: "List scanners"),
                    ExampleDTO(command: "scanner list --timeout 15", description: "Search for 15 seconds"),
                ]
            ),
        ]
    }
}
