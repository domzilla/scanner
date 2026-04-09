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
    func loadConfigurationFromFile() throws {
        let path = makeTempConfigFile(contents: "--duplex\n--name\nthe_name\n")
        let config = try ScanConfiguration(arguments: [], configFilePath: path)

        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.string(.name) == "the_name")
    }

    @Test
    func loadConfigurationFromFileWithArgumentOverride() throws {
        let path = makeTempConfigFile(contents: "--duplex\n--name\nthe_name\n")
        let config = try ScanConfiguration(arguments: ["--input", "flatbed"], configFilePath: path)

        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
        #expect(config.string(.name) == "the_name")
    }

    @Test
    func configFileNotFound() throws {
        let config = try ScanConfiguration(arguments: [], configFilePath: "/nonexistent/path.conf")
        #expect(config.flag(.duplex) == false)
        #expect(config.string(.resolution) == "150")
    }

    @Test
    func configFileWithEmptyLines() throws {
        let path = makeTempConfigFile(contents: "\n\n--batch\n\n--color\nmono\n\n")
        let config = try ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.flag(.batch) == true)
        #expect(config.string(.color) == "mono")
    }

    @Test
    func configFileWithMultipleOptions() throws {
        let path =
            makeTempConfigFile(contents: "--duplex\n--input\nflatbed\n--format\njpeg\n--verbose\n--resolution\n300\n")
        let config = try ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
        #expect(config.string(.format) == "jpeg")
        #expect(config.flag(.verbose) == true)
        #expect(config.string(.resolution) == "300")
    }

    // MARK: - Default Values

    @Test
    func defaultEnumOptions() throws {
        let config = try makeConfig([])
        #expect(config.string(.input) == "feeder")
        #expect(config.string(.format) == "pdf")
        #expect(config.string(.size) == "a4")
        #expect(config.string(.color) == "color")
    }

    @Test
    func defaultResolution() throws {
        let config = try makeConfig([])
        #expect(config.string(.resolution) == "150")
    }

    @Test
    func defaultRotate() throws {
        let config = try makeConfig([])
        #expect(config.string(.rotate) == "0")
    }

    @Test
    func defaultMRCResolution() throws {
        let config = try makeConfig([])
        #expect(config.string(.mrcResolution) == "400")
    }

    @Test
    func defaultNoMRCFlagIsFalse() throws {
        let config = try makeConfig([])
        #expect(config.flag(.noMRC) == false)
    }

    @Test
    func noMRCFlagSet() throws {
        let config = try makeConfig(["--no-mrc"])
        #expect(config.flag(.noMRC) == true)
    }

    @Test
    func mrcResolutionOverride() throws {
        let config = try makeConfig(["--mrc-resolution", "600"])
        #expect(config.string(.mrcResolution) == "600")
    }

    @Test
    func mrcWithCustomBackgroundResolution() throws {
        let config = try makeConfig(["--resolution", "200", "--mrc-resolution", "500"])
        #expect(config.flag(.noMRC) == false)
        #expect(config.string(.resolution) == "200")
        #expect(config.string(.mrcResolution) == "500")
    }

    @Test
    func defaultJPEGQuality() throws {
        let config = try makeConfig([])
        #expect(config.string(.jpegQuality) == "60")
    }

    @Test
    func jpegQualityOverride() throws {
        let config = try makeConfig(["--jpeg-quality", "85"])
        #expect(config.string(.jpegQuality) == "85")
    }

    @Test
    func jpegQualityAcceptsNonNumericStringForLaterHandling() throws {
        // The parser doesn't validate numeric values (matches --resolution behavior);
        // PDFAssembler is responsible for clamping / falling back at use time.
        let config = try makeConfig(["--jpeg-quality", "garbage"])
        #expect(config.string(.jpegQuality) == "garbage")
    }

    @Test
    func defaultMRCJPEGQuality() throws {
        let config = try makeConfig([])
        #expect(config.string(.mrcJpegQuality) == "20")
    }

    @Test
    func mrcJpegQualityOverride() throws {
        let config = try makeConfig(["--mrc-jpeg-quality", "35"])
        #expect(config.string(.mrcJpegQuality) == "35")
    }

    @Test
    func mrcJpegQualityAcceptsNonNumericStringForLaterHandling() throws {
        // Same rationale as --jpeg-quality: the parser leaves validation to
        // PDFAssembler so that non-numeric values degrade to the default at use time.
        let config = try makeConfig(["--mrc-jpeg-quality", "garbage"])
        #expect(config.string(.mrcJpegQuality) == "garbage")
    }

    @Test
    func jpegAndMRCJpegQualityAreIndependent() throws {
        let config = try makeConfig(["--jpeg-quality", "75", "--mrc-jpeg-quality", "15"])
        #expect(config.string(.jpegQuality) == "75")
        #expect(config.string(.mrcJpegQuality) == "15")
    }

    // MARK: - isMRCEnabled helper

    @Test
    func isMRCEnabledDefaultsToTrueForPDF() throws {
        let config = try makeConfig([])
        #expect(config.isMRCEnabled == true)
    }

    @Test
    func isMRCEnabledFalseWithNoMRCFlag() throws {
        let config = try makeConfig(["--no-mrc"])
        #expect(config.isMRCEnabled == false)
    }

    @Test
    func isMRCEnabledFalseForJPEGFormat() throws {
        let config = try makeConfig(["--format", "jpeg"])
        #expect(config.isMRCEnabled == false)
    }

    @Test
    func isMRCEnabledFalseForPNGFormat() throws {
        let config = try makeConfig(["--format", "png"])
        #expect(config.isMRCEnabled == false)
    }

    @Test
    func isMRCEnabledFalseForTIFFFormat() throws {
        let config = try makeConfig(["--format", "tiff"])
        #expect(config.isMRCEnabled == false)
    }

    @Test
    func isMRCEnabledFalseWhenBothNoMRCAndNonPDF() throws {
        let config = try makeConfig(["--no-mrc", "--format", "jpeg"])
        #expect(config.isMRCEnabled == false)
    }

    @Test
    func noDefaultForNameAndScanner() throws {
        let config = try makeConfig([])
        #expect(config.string(.name) == nil)
        #expect(config.string(.scanner) == nil)
    }

    @Test
    func debugInputParsesPath() throws {
        let config = try makeConfig(["--debug-input", "/tmp/pages/scan.jpg"])
        #expect(config.string(.debugInput) == "/tmp/pages/scan.jpg")
    }

    @Test
    func debugInputHasNoDefault() throws {
        let config = try makeConfig([])
        #expect(config.string(.debugInput) == nil)
    }

    @Test
    func defaultsOverriddenByCLI() throws {
        let config = try makeConfig(["--resolution", "600", "--rotate", "90"])
        #expect(config.string(.resolution) == "600")
        #expect(config.string(.rotate) == "90")
    }

    // MARK: - Flag Options

    @Test
    func allFlagOptionsIndividually() throws {
        let flags: [(String, ConfigOption)] = [
            ("--duplex", .duplex),
            ("--batch", .batch),
            ("--verbose", .verbose),
            ("--exactname", .exactName),
        ]
        for (arg, option) in flags {
            let config = try makeConfig([arg])
            #expect(config.flag(option) == true, "Expected \(arg) to set \(option)")
        }
    }

    @Test
    func unsetFlagsAreFalse() throws {
        let config = try makeConfig([])
        let allFlags: [ConfigOption] = [
            .duplex, .batch, .verbose, .exactName,
        ]
        for option in allFlags {
            #expect(config.flag(option) == false, "\(option) should be false by default")
        }
    }

    @Test
    func flagReturnsFalseForStringOptions() throws {
        let config = try makeConfig(["--name", "test", "--resolution", "300"])
        #expect(config.flag(.name) == false)
        #expect(config.flag(.resolution) == false)
        #expect(config.flag(.rotate) == false)
        #expect(config.flag(.rotate) == false)
        #expect(config.flag(.scanner) == false)
    }

    @Test
    func multipleFlagsCombined() throws {
        let config = try makeConfig(["--duplex", "--verbose", "--exactname"])
        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.verbose) == true)
        #expect(config.flag(.exactName) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.flag(.batch) == false)
    }

    // MARK: - Enum Options

    @Test
    func inputOption() throws {
        let config = try makeConfig(["--input", "flatbed"])
        #expect(config.string(.input) == "flatbed")
    }

    @Test
    func formatOption() throws {
        let config = try makeConfig(["--format", "jpeg"])
        #expect(config.string(.format) == "jpeg")
    }

    @Test
    func sizeOption() throws {
        let config = try makeConfig(["--size", "letter"])
        #expect(config.string(.size) == "letter")
    }

    @Test
    func colorOption() throws {
        let config = try makeConfig(["--color", "mono"])
        #expect(config.string(.color) == "mono")
    }

    @Test
    func allFormatValues() throws {
        for format in ["pdf", "jpeg", "tiff", "png"] {
            let config = try makeConfig(["--format", format])
            #expect(config.string(.format) == format)
        }
    }

    @Test
    func allSizeValues() throws {
        for size in ["a4", "letter", "legal"] {
            let config = try makeConfig(["--size", size])
            #expect(config.string(.size) == size)
        }
    }

    @Test
    func allColorValues() throws {
        for color in ["color", "mono"] {
            let config = try makeConfig(["--color", color])
            #expect(config.string(.color) == color)
        }
    }

    @Test
    func allInputValues() throws {
        for input in ["feeder", "flatbed"] {
            let config = try makeConfig(["--input", input])
            #expect(config.string(.input) == input)
        }
    }

    @Test
    func invalidEnumValueThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.invalidValue("--format", "jpeg, pdf, png, tiff")) {
            try ScanConfiguration.parse(arguments: ["--format", "bmp"], into: &config)
        }
    }

    @Test
    func enumOptionOverridesDefault() throws {
        let config = try makeConfig(["--format", "png"])
        #expect(config.string(.format) == "png")
    }

    // MARK: - String Options

    @Test
    func nameOption() throws {
        let config = try makeConfig(["--name", "my_document"])
        #expect(config.string(.name) == "my_document")
    }

    @Test
    func scannerOption() throws {
        let config = try makeConfig(["--scanner", "Epson"])
        #expect(config.string(.scanner) == "Epson")
    }

    @Test
    func resolutionOption() throws {
        let config = try makeConfig(["--resolution", "300"])
        #expect(config.string(.resolution) == "300")
    }

    @Test
    func rotateOption() throws {
        let config = try makeConfig(["--rotate", "180"])
        #expect(config.string(.rotate) == "180")
    }

    @Test
    func stringReturnsNilForUnsetOptions() throws {
        let config = try makeConfig([])
        #expect(config.string(.name) == nil)
        #expect(config.string(.scanner) == nil)
    }

    @Test
    func stringReturnsNilForFlagOptions() throws {
        let config = try makeConfig(["--duplex"])
        #expect(config.string(.duplex) == nil)
    }

    // MARK: - Short Flags

    @Test
    func shortFlagForBooleanOption() throws {
        let config = try makeConfig(["-d"])
        #expect(config.flag(.duplex) == true)
    }

    @Test
    func shortFlagForStringOption() throws {
        let config = try makeConfig(["-f", "jpeg"])
        #expect(config.string(.format) == "jpeg")
    }

    @Test
    func mixedShortAndLongFlags() throws {
        let config = try makeConfig(["-d", "--name", "scan", "-f", "png"])
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.name) == "scan")
        #expect(config.string(.format) == "png")
    }

    @Test
    func unknownShortFlagThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.unknownOption("-x")) {
            try ScanConfiguration.parse(arguments: ["-x"], into: &config)
        }
    }

    @Test
    func singleDashMultiCharThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.unknownOption("-duplex")) {
            try ScanConfiguration.parse(arguments: ["-duplex"], into: &config)
        }
    }

    // MARK: - Edge Cases

    @Test
    func emptyArguments() throws {
        let config = try makeConfig([])
        #expect(config.flag(.duplex) == false)
        #expect(config.string(.resolution) == "150")
    }

    @Test
    func resolutionOptionWithNonNumericalValue() throws {
        let config = try makeConfig(["--resolution", "booger"])
        #expect(config.string(.resolution) == "booger")
        #expect(Int(config.string(.resolution) ?? "") == nil)
    }

    @Test
    func missingValueThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.missingValue("--scanner")) {
            try ScanConfiguration.parse(arguments: ["--scanner"], into: &config)
        }
    }

    @Test
    func unknownOptionThrows() {
        var config: [ConfigOption: ConfigValue] = [:]
        #expect(throws: ConfigError.unknownOption("--unknown")) {
            try ScanConfiguration.parse(arguments: ["--unknown"], into: &config)
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
        #expect(throws: ConfigError.missingValue("--name")) {
            try ScanConfiguration.parse(arguments: ["--duplex", "--name"], into: &config)
        }
    }

    @Test
    func multipleStringOptions() throws {
        let config = try makeConfig(["--name", "invoice", "--scanner", "Epson", "--resolution", "600"])
        #expect(config.string(.name) == "invoice")
        #expect(config.string(.scanner) == "Epson")
        #expect(config.string(.resolution) == "600")
    }

    @Test
    func mixedFlagsAndStrings() throws {
        let config = try makeConfig([
            "--duplex",
            "--name",
            "scan",
            "--input",
            "flatbed",
            "--resolution",
            "300",
            "--verbose",
        ])
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
        #expect(config.flag(.verbose) == true)
        #expect(config.string(.name) == "scan")
        #expect(config.string(.resolution) == "300")
    }

    @Test
    func duplicateOptionLastWins() throws {
        let config = try makeConfig(["--resolution", "150", "--resolution", "600"])
        #expect(config.string(.resolution) == "600")
    }

    // MARK: - Three-Layer Precedence

    @Test
    func cliOverridesConfigFile() throws {
        let path = makeTempConfigFile(contents: "--name\nfrom_file\n--resolution\n200\n")
        let config = try ScanConfiguration(arguments: ["--name", "from_cli"], configFilePath: path)
        #expect(config.string(.name) == "from_cli")
        #expect(config.string(.resolution) == "200")
    }

    @Test
    func configFileOverridesDefaults() throws {
        let path = makeTempConfigFile(contents: "--resolution\n600\n")
        let config = try ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.string(.resolution) == "600")
    }

    @Test
    func fullThreeLayerPrecedence() throws {
        let path = makeTempConfigFile(contents: "--resolution\n300\n--rotate\n45\n")
        let config = try ScanConfiguration(arguments: ["--resolution", "600"], configFilePath: path)
        #expect(config.string(.resolution) == "600")
        #expect(config.string(.rotate) == "45")
    }

    @Test
    func configFileFlagPersistsWithCLIAdditions() throws {
        let path = makeTempConfigFile(contents: "--duplex\n")
        let config = try ScanConfiguration(arguments: ["--input", "flatbed"], configFilePath: path)
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.input) == "flatbed")
    }
}
