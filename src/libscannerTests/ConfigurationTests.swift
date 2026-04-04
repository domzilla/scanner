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
        #expect(config.flag(.flatbed) == false)
        #expect(config.string(.name) == "the_name")
    }

    @Test
    func loadConfigurationFromFileWithArgumentOverride() {
        let path = makeTempConfigFile(contents: "-duplex\n-name\nthe_name\n")
        let config = ScanConfiguration(arguments: ["-flatbed"], configFilePath: path)

        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.flag(.flatbed) == true)
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
        let path = makeTempConfigFile(contents: "\n\n-batch\n\n-mono\n\n")
        let config = ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.flag(.batch) == true)
        #expect(config.flag(.mono) == true)
    }

    @Test
    func configFileWithMultipleOptions() {
        let path = makeTempConfigFile(contents: "-duplex\n-flatbed\n-jpeg\n-verbose\n-resolution\n300\n")
        let config = ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.flatbed) == true)
        #expect(config.flag(.jpeg) == true)
        #expect(config.flag(.verbose) == true)
        #expect(config.string(.resolution) == "300")
    }

    @Test
    func configFileSynonyms() {
        let path = makeTempConfigFile(contents: "-dup\n-fb\n-jpg\n-bw\n-v\n-res\n300\n")
        let config = ScanConfiguration(arguments: [], configFilePath: path)
        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.flatbed) == true)
        #expect(config.flag(.jpeg) == true)
        #expect(config.flag(.mono) == true)
        #expect(config.flag(.verbose) == true)
        #expect(config.string(.resolution) == "300")
    }

    // MARK: - Default Values

    @Test
    func defaultResolution() {
        let config = makeConfig([])
        #expect(config.string(.resolution) == "150")
    }

    @Test
    func defaultBrowseSecs() {
        let config = makeConfig([])
        #expect(config.string(.browseSecs) == "10")
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
        let config = makeConfig(["-resolution", "600", "-browsesecs", "20", "-rotate", "90"])
        #expect(config.string(.resolution) == "600")
        #expect(config.string(.browseSecs) == "20")
        #expect(config.string(.rotate) == "90")
    }

    // MARK: - Flag Options

    @Test
    func allFlagOptionsIndividually() {
        let flags: [(String, ConfigOption)] = [
            ("-duplex", .duplex),
            ("-batch", .batch),
            ("-list", .list),
            ("-flatbed", .flatbed),
            ("-jpeg", .jpeg),
            ("-tiff", .tiff),
            ("-png", .png),
            ("-legal", .legal),
            ("-letter", .letter),
            ("-a4", .a4),
            ("-mono", .mono),
            ("-open", .open),
            ("-verbose", .verbose),
            ("-exactname", .exactName),
            ("-ocr", .ocr),
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
            .duplex, .batch, .list, .flatbed, .jpeg, .tiff, .png,
            .legal, .letter, .a4, .mono, .open, .verbose, .exactName, .ocr,
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
        #expect(config.flag(.browseSecs) == false)
        #expect(config.flag(.rotate) == false)
        #expect(config.flag(.scanner) == false)
    }

    @Test
    func multipleFlagsCombined() {
        let config = makeConfig(["-duplex", "-flatbed", "-jpeg", "-mono", "-verbose"])
        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.flatbed) == true)
        #expect(config.flag(.jpeg) == true)
        #expect(config.flag(.mono) == true)
        #expect(config.flag(.verbose) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.flag(.list) == false)
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
    func browseSecsOption() {
        let config = makeConfig(["-browsesecs", "5"])
        #expect(config.string(.browseSecs) == "5")
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
        let config = makeConfig(["-duplex", "-jpeg"])
        #expect(config.string(.duplex) == nil)
        #expect(config.string(.jpeg) == nil)
    }

    // MARK: - Synonym Support

    @Test
    func jpegOption() {
        let config = makeConfig(["-jpeg"])
        #expect(config.flag(.jpeg) == true)
    }

    @Test
    func jpegOptionWithJpgSynonym() {
        let config = makeConfig(["-jpg"])
        #expect(config.flag(.jpeg) == true)
    }

    @Test
    func duplexWithDupSynonym() {
        let config = makeConfig(["-dup"])
        #expect(config.flag(.duplex) == true)
    }

    @Test
    func flatbedWithFbSynonym() {
        let config = makeConfig(["-fb"])
        #expect(config.flag(.flatbed) == true)
    }

    @Test
    func tiffWithTifSynonym() {
        let config = makeConfig(["-tif"])
        #expect(config.flag(.tiff) == true)
    }

    @Test
    func monoWithBwSynonym() {
        let config = makeConfig(["-bw"])
        #expect(config.flag(.mono) == true)
    }

    @Test
    func verboseWithVSynonym() {
        let config = makeConfig(["-v"])
        #expect(config.flag(.verbose) == true)
    }

    @Test
    func scannerWithSSynonym() {
        let config = makeConfig(["-s", "Canon"])
        #expect(config.string(.scanner) == "Canon")
    }

    @Test
    func resolutionWithResSynonym() {
        let config = makeConfig(["-res", "600"])
        #expect(config.string(.resolution) == "600")
    }

    @Test
    func resolutionWithMinResolutionSynonym() {
        let config = makeConfig(["-minResolution", "1200"])
        #expect(config.string(.resolution) == "1200")
    }

    @Test
    func browseSecsWithTimeSynonym() {
        let config = makeConfig(["-time", "15"])
        #expect(config.string(.browseSecs) == "15")
    }

    @Test
    func browseSecsWithTSynonym() {
        let config = makeConfig(["-t", "3"])
        #expect(config.string(.browseSecs) == "3")
    }

    @Test
    func exactNameWithExactSynonym() {
        let config = makeConfig(["-exact"])
        #expect(config.flag(.exactName) == true)
    }

    // MARK: - Page Sizes

    @Test
    func letterNotLegal() {
        let config = makeConfig(["-letter"])
        #expect(config.flag(.letter) == true)
        #expect(config.flag(.legal) == false)
    }

    @Test
    func legalNotLetter() {
        let config = makeConfig(["-legal"])
        #expect(config.flag(.letter) == false)
        #expect(config.flag(.legal) == true)
    }

    @Test
    func a4NotLetterOrLegal() {
        let config = makeConfig(["-a4"])
        #expect(config.flag(.a4) == true)
        #expect(config.flag(.letter) == false)
        #expect(config.flag(.legal) == false)
    }

    @Test
    func multipleSizesAllSet() {
        let config = makeConfig(["-letter", "-legal", "-a4"])
        #expect(config.flag(.letter) == true)
        #expect(config.flag(.legal) == true)
        #expect(config.flag(.a4) == true)
    }

    // MARK: - Format Options

    @Test
    func jpegFormat() {
        let config = makeConfig(["-jpeg"])
        #expect(config.flag(.jpeg) == true)
        #expect(config.flag(.tiff) == false)
        #expect(config.flag(.png) == false)
    }

    @Test
    func tiffFormat() {
        let config = makeConfig(["-tiff"])
        #expect(config.flag(.tiff) == true)
        #expect(config.flag(.jpeg) == false)
        #expect(config.flag(.png) == false)
    }

    @Test
    func pngFormat() {
        let config = makeConfig(["-png"])
        #expect(config.flag(.png) == true)
        #expect(config.flag(.jpeg) == false)
        #expect(config.flag(.tiff) == false)
    }

    @Test
    func defaultFormatIsPDF() {
        let config = makeConfig([])
        #expect(config.flag(.jpeg) == false)
        #expect(config.flag(.tiff) == false)
        #expect(config.flag(.png) == false)
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
    func missingSecondParameter() {
        _ = makeConfig(["-scanner"])
        let config = makeConfig(["-scanner", "epson"])
        #expect(config.string(.scanner) == "epson")
    }

    @Test
    func unknownOptionIgnored() {
        let config = makeConfig(["-unknown", "-duplex"])
        #expect(config.flag(.duplex) == true)
    }

    @Test
    func unknownArgumentIgnored() {
        let config = makeConfig(["random_text", "-batch"])
        #expect(config.flag(.batch) == true)
    }

    @Test
    func stringOptionAtEndWithoutValue() {
        let config = makeConfig(["-duplex", "-name"])
        #expect(config.flag(.duplex) == true)
        #expect(config.string(.name) == nil)
    }

    @Test
    func stringOptionValueLooksLikeFlag() {
        let config = makeConfig(["-name", "-jpeg"])
        #expect(config.string(.name) == "-jpeg")
        #expect(config.flag(.jpeg) == false)
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
        let config = makeConfig(["-duplex", "-name", "scan", "-flatbed", "-resolution", "300", "-verbose"])
        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.flatbed) == true)
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
        let path = makeTempConfigFile(contents: "-resolution\n300\n-browsesecs\n5\n")
        let config = ScanConfiguration(arguments: ["-resolution", "600"], configFilePath: path)
        #expect(config.string(.resolution) == "600")
        #expect(config.string(.browseSecs) == "5")
        #expect(config.string(.rotate) == "0")
    }

    @Test
    func configFileFlagPersistsWithCLIAdditions() {
        let path = makeTempConfigFile(contents: "-duplex\n")
        let config = ScanConfiguration(arguments: ["-flatbed"], configFilePath: path)
        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.flatbed) == true)
    }
}
