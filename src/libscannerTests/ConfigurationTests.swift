//
//  ConfigurationTests.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 04.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import libscanner

struct ConfigurationTests {
    // MARK: - Config File Loading

    @Test
    func loadConfigurationFromFile() {
        let path = makeTempConfigFile(contents: "-duplex\n-name\nthe_name\n")
        let config = ScanConfiguration(arguments: [], configFilePath: path)

        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.string(.name) == "the_name")
    }

    @Test
    func loadConfigurationFromFileWithArgumentOverride() {
        let path = makeTempConfigFile(contents: "-duplex\n-name\nthe_name\n")
        let config = ScanConfiguration(arguments: ["-input", "flatbed"], configFilePath: path)

        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
        #expect(config.string(.name) == "the_name")
    }

    @Test
    func configFileNotFound() {
        let config = ScanConfiguration(arguments: [], configFilePath: "/nonexistent/path.conf")
        #expect(config.flag(.duplex) == false)
        #expect(config.string(.resolution) == "150")
    }

    @Test
    func configFileWithEmptyLines() {
        let path = makeTempConfigFile(contents: "\n\n-batch\n\n-color\nmono\n\n")
        let config = ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.flag(.batch) == true)
        #expect(config.string(.color) == "mono")
    }

    @Test
    func configFileWithMultipleOptions() {
        let path = makeTempConfigFile(contents: "-duplex\n-input\nflatbed\n-format\njpeg\n-verbose\n-resolution\n300\n")
        let config = ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
        #expect(config.string(.format) == "jpeg")
        #expect(config.flag(.verbose) == true)
        #expect(config.string(.resolution) == "300")
    }

    // MARK: - Default Values

    @Test
    func defaultEnumOptions() {
        let config = makeConfig([])
        #expect(config.string(.input) == "feeder")
        #expect(config.string(.format) == "pdf")
        #expect(config.string(.size) == "a4")
        #expect(config.string(.color) == "color")
    }

    @Test
    func defaultResolution() {
        let config = makeConfig([])
        #expect(config.string(.resolution) == "150")
    }

    @Test
    func defaultRotate() {
        let config = makeConfig([])
        #expect(config.string(.rotate) == "0")
    }

    @Test
    func noDefaultForNameAndScanner() {
        let config = makeConfig([])
        #expect(config.string(.name) == nil)
        #expect(config.string(.scanner) == nil)
    }

    @Test
    func defaultsOverriddenByCLI() {
        let config = makeConfig(["-resolution", "600", "-rotate", "90"])
        #expect(config.string(.resolution) == "600")
        #expect(config.string(.rotate) == "90")
    }

    // MARK: - Flag Options

    @Test
    func allFlagOptionsIndividually() {
        let flags: [(String, ConfigOption)] = [
            ("-duplex", .duplex),
            ("-batch", .batch),
            ("-open", .open),
            ("-verbose", .verbose),
            ("-exactname", .exactName),
        ]
        for (arg, option) in flags {
            let config = makeConfig([arg])
            #expect(config.flag(option) == true, "Expected \(arg) to set \(option)")
        }
    }

    @Test
    func unsetFlagsAreFalse() {
        let config = makeConfig([])
        let allFlags: [ConfigOption] = [
            .duplex, .batch, .open, .verbose, .exactName,
        ]
        for option in allFlags {
            #expect(config.flag(option) == false, "\(option) should be false by default")
        }
    }

    @Test
    func flagReturnsFalseForStringOptions() {
        let config = makeConfig(["-name", "test", "-resolution", "300"])
        #expect(config.flag(.name) == false)
        #expect(config.flag(.resolution) == false)
        #expect(config.flag(.rotate) == false)
        #expect(config.flag(.rotate) == false)
        #expect(config.flag(.scanner) == false)
    }

    @Test
    func multipleFlagsCombined() {
        let config = makeConfig(["-duplex", "-verbose", "-open"])
        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.verbose) == true)
        #expect(config.flag(.open) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.flag(.batch) == false)
    }

    // MARK: - Enum Options

    @Test
    func inputOption() {
        let config = makeConfig(["-input", "flatbed"])
        #expect(config.string(.input) == "flatbed")
    }

    @Test
    func formatOption() {
        let config = makeConfig(["-format", "jpeg"])
        #expect(config.string(.format) == "jpeg")
    }

    @Test
    func sizeOption() {
        let config = makeConfig(["-size", "letter"])
        #expect(config.string(.size) == "letter")
    }

    @Test
    func colorOption() {
        let config = makeConfig(["-color", "mono"])
        #expect(config.string(.color) == "mono")
    }

    @Test
    func allFormatValues() {
        for format in ["pdf", "jpeg", "tiff", "png"] {
            let config = makeConfig(["-format", format])
            #expect(config.string(.format) == format)
        }
    }

    @Test
    func allSizeValues() {
        for size in ["a4", "letter", "legal"] {
            let config = makeConfig(["-size", size])
            #expect(config.string(.size) == size)
        }
    }

    @Test
    func allColorValues() {
        for color in ["color", "mono"] {
            let config = makeConfig(["-color", color])
            #expect(config.string(.color) == color)
        }
    }

    @Test
    func allInputValues() {
        for input in ["feeder", "flatbed"] {
            let config = makeConfig(["-input", input])
            #expect(config.string(.input) == input)
        }
    }

    @Test
    func invalidEnumValueThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.invalidValue("-format", "jpeg, pdf, png, tiff")) {
            try ScanConfiguration.parse(arguments: ["-format", "bmp"], into: &config)
        }
    }

    @Test
    func enumOptionOverridesDefault() {
        let config = makeConfig(["-format", "png"])
        #expect(config.string(.format) == "png")
    }

    // MARK: - String Options

    @Test
    func nameOption() {
        let config = makeConfig(["-name", "my_document"])
        #expect(config.string(.name) == "my_document")
    }

    @Test
    func scannerOption() {
        let config = makeConfig(["-scanner", "Epson"])
        #expect(config.string(.scanner) == "Epson")
    }

    @Test
    func resolutionOption() {
        let config = makeConfig(["-resolution", "300"])
        #expect(config.string(.resolution) == "300")
    }

    @Test
    func rotateOption() {
        let config = makeConfig(["-rotate", "180"])
        #expect(config.string(.rotate) == "180")
    }

    @Test
    func stringReturnsNilForUnsetOptions() {
        let config = makeConfig([])
        #expect(config.string(.name) == nil)
        #expect(config.string(.scanner) == nil)
    }

    @Test
    func stringReturnsNilForFlagOptions() {
        let config = makeConfig(["-duplex"])
        #expect(config.string(.duplex) == nil)
    }

    // MARK: - Edge Cases

    @Test
    func emptyArguments() {
        let config = makeConfig([])
        #expect(config.flag(.duplex) == false)
        #expect(config.string(.resolution) == "150")
    }

    @Test
    func resolutionOptionWithNonNumericalValue() {
        let config = makeConfig(["-resolution", "booger"])
        #expect(config.string(.resolution) == "booger")
        #expect(Int(config.string(.resolution) ?? "") == nil)
    }

    @Test
    func missingValueThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.missingValue("-scanner")) {
            try ScanConfiguration.parse(arguments: ["-scanner"], into: &config)
        }
    }

    @Test
    func unknownOptionThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.unknownOption("-unknown")) {
            try ScanConfiguration.parse(arguments: ["-unknown"], into: &config)
        }
    }

    @Test
    func unknownArgumentThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.unknownArgument("random_text")) {
            try ScanConfiguration.parse(arguments: ["random_text"], into: &config)
        }
    }

    @Test
    func stringOptionAtEndThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.missingValue("-name")) {
            try ScanConfiguration.parse(arguments: ["-duplex", "-name"], into: &config)
        }
    }

    @Test
    func multipleStringOptions() {
        let config = makeConfig(["-name", "invoice", "-scanner", "Epson", "-resolution", "600"])
        #expect(config.string(.name) == "invoice")
        #expect(config.string(.scanner) == "Epson")
        #expect(config.string(.resolution) == "600")
    }

    @Test
    func mixedFlagsAndStrings() {
        let config = makeConfig(["-duplex", "-name", "scan", "-input", "flatbed", "-resolution", "300", "-verbose"])
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
        #expect(config.flag(.verbose) == true)
        #expect(config.string(.name) == "scan")
        #expect(config.string(.resolution) == "300")
    }

    @Test
    func duplicateOptionLastWins() {
        let config = makeConfig(["-resolution", "150", "-resolution", "600"])
        #expect(config.string(.resolution) == "600")
    }

    // MARK: - Three-Layer Precedence

    @Test
    func cliOverridesConfigFile() {
        let path = makeTempConfigFile(contents: "-name\nfrom_file\n-resolution\n200\n")
        let config = ScanConfiguration(arguments: ["-name", "from_cli"], configFilePath: path)
        #expect(config.string(.name) == "from_cli")
        #expect(config.string(.resolution) == "200")
    }

    @Test
    func configFileOverridesDefaults() {
        let path = makeTempConfigFile(contents: "-resolution\n600\n")
        let config = ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.string(.resolution) == "600")
    }

    @Test
    func fullThreeLayerPrecedence() {
        let path = makeTempConfigFile(contents: "-resolution\n300\n-rotate\n45\n")
        let config = ScanConfiguration(arguments: ["-resolution", "600"], configFilePath: path)
        #expect(config.string(.resolution) == "600")
        #expect(config.string(.rotate) == "45")
    }

    @Test
    func configFileFlagPersistsWithCLIAdditions() {
        let path = makeTempConfigFile(contents: "-duplex\n")
        let config = ScanConfiguration(arguments: ["-input", "flatbed"], configFilePath: path)
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
    }
}
