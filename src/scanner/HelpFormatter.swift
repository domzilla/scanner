//
//  HelpFormatter.swift
//  scanner
//
//  Created by Dominic Rodemer on 07.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

// MARK: - Help DTOs

struct HelpCommandDTO {
    let command: String
    let description: String
}

struct ParameterInfoDTO {
    let name: String
    let shortFlag: String?
    let type: String
    let required: Bool
    let description: String
}

struct OptionGroupDTO {
    let title: String
    let parameters: [ParameterInfoDTO]
}

struct ExampleDTO {
    let command: String
    let description: String
}

struct CommandInfoDTO {
    let command: String
    let description: String
    let parameters: [ParameterInfoDTO]?
    let output: OutputInfoDTO?
    let examples: [ExampleDTO]?
}

struct OutputInfoDTO {
    let description: String
    let fields: [String: String]?
}

// MARK: - HelpFormatter

enum HelpFormatter {
    // MARK: - Main Help

    static func formatMainHelp(
        title: String,
        usage: [String],
        description: String,
        configFile: String,
        commands: [HelpCommandDTO],
        optionGroups: [OptionGroupDTO],
        examples: [ExampleDTO]
    )
        -> String
    {
        var lines: [String] = []

        lines.append(title)
        lines.append("")

        for (index, usageLine) in usage.enumerated() {
            if index == 0 {
                lines.append("Usage: \(usageLine)")
            } else {
                lines.append("       \(usageLine)")
            }
        }
        lines.append("")

        lines.append(description)
        lines.append("Config file: \(configFile)")
        lines.append("")

        // Commands
        let baseCommand = commands.first?.command.components(separatedBy: " ").first ?? "scanner"
        lines.append("Commands:")
        let displayCommands = commands.map { cmd -> (name: String, desc: String) in
            let name = cmd.command.replacingOccurrences(of: "\(baseCommand) ", with: "")
            return (name, cmd.description)
        }
        let maxCmdWidth = displayCommands.map(\.name.count).max() ?? 0
        let cmdColumnWidth = maxCmdWidth + 4
        for cmd in displayCommands {
            let padding = String(repeating: " ", count: max(cmdColumnWidth - cmd.name.count, 2))
            lines.append("  \(cmd.name)\(padding)\(cmd.desc)")
        }
        lines.append("")

        // Option Groups
        for group in optionGroups {
            lines.append("\(group.title):")
            self.appendFormattedParameters(group.parameters, to: &lines)
            lines.append("")
        }

        // Examples
        lines.append("Examples:")
        let maxExCmd = examples.map(\.command.count).max() ?? 0
        let exColumnWidth = maxExCmd + 4
        for example in examples {
            let padding = String(repeating: " ", count: max(exColumnWidth - example.command.count, 2))
            lines.append("  \(example.command)\(padding)\(example.description)")
        }
        lines.append("")

        lines.append("Use '\(baseCommand) <command> -h' for detailed help on a specific command.")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    // MARK: - Command Help

    static func formatCommandHelp(_ cmd: CommandInfoDTO) -> String {
        var lines: [String] = []

        // Usage
        var usage = cmd.command
        let hasOptions = cmd.parameters?.contains(where: { !$0.name.hasPrefix("<") }) == true
        if hasOptions {
            usage += " [options]"
        }
        lines.append("Usage: \(usage)")
        lines.append("")

        // Description
        lines.append(cmd.description)
        lines.append("")

        // Parameters
        if let params = cmd.parameters, !params.isEmpty {
            let positionalParams = params.filter { $0.name.hasPrefix("<") }
            let flagParams = params.filter { !$0.name.hasPrefix("<") }

            if !positionalParams.isEmpty {
                lines.append("Arguments:")
                for param in positionalParams {
                    let req = param.required ? " (required)" : ""
                    lines.append("  \(param.name)  \(param.description)\(req)")
                }
                lines.append("")
            }

            if !flagParams.isEmpty {
                lines.append("Options:")
                self.appendFormattedParameters(flagParams, to: &lines)
                lines.append("")
            }
        }

        // Examples
        if let examples = cmd.examples, !examples.isEmpty {
            lines.append("Examples:")
            let maxCmd = examples.map(\.command.count).max() ?? 0
            let exColumnWidth = maxCmd + 4
            for example in examples {
                let padding = String(repeating: " ", count: max(exColumnWidth - example.command.count, 2))
                lines.append("  \(example.command)\(padding)\(example.description)")
            }
            lines.append("")
        }

        // Output
        if let output = cmd.output {
            lines.append("Output: \(output.description)")

            if let fields = output.fields, !fields.isEmpty {
                lines.append("")
                lines.append("Fields:")
                let sortedFields = fields.sorted(by: { $0.key < $1.key })
                let maxField = sortedFields.map(\.key.count).max() ?? 0
                let columnWidth = maxField + 4
                for (key, value) in sortedFields {
                    let padding = String(repeating: " ", count: max(columnWidth - key.count, 2))
                    lines.append("  \(key)\(padding)\(value)")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Output

    static func printAndExit(_ text: String) -> Never {
        FileHandle.standardOutput.write(Data(text.utf8))
        exit(0)
    }

    // MARK: - Private

    private static func appendFormattedParameters(
        _ parameters: [ParameterInfoDTO],
        to lines: inout [String]
    ) {
        let hasAnyShortFlag = parameters.contains(where: { $0.shortFlag != nil })

        let formatted = parameters.map { param -> (label: String, desc: String, required: Bool) in
            let prefix: String = if let short = param.shortFlag {
                "\(short), \(param.name)"
            } else if hasAnyShortFlag {
                "    \(param.name)"
            } else {
                param.name
            }
            let label: String = if param.type == "flag" {
                prefix
            } else {
                "\(prefix) <\(param.type)>"
            }
            return (label, param.description, param.required)
        }

        let maxLabel = formatted.map(\.label.count).max() ?? 0
        let columnWidth = maxLabel + 4

        for param in formatted {
            let padding = String(repeating: " ", count: max(columnWidth - param.label.count, 2))
            let req = param.required ? " (required)" : ""
            lines.append("  \(param.label)\(padding)\(param.desc)\(req)")
        }
    }
}
