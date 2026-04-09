//
//  ConfigOptionTests.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 04.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import libscanner

struct ConfigOptionTests {
    @Test
    func fromRawValue() {
        #expect(ConfigOption.from(key: "input") == .input)
        #expect(ConfigOption.from(key: "duplex") == .duplex)
        #expect(ConfigOption.from(key: "batch") == .batch)
        #expect(ConfigOption.from(key: "format") == .format)
        #expect(ConfigOption.from(key: "size") == .size)
        #expect(ConfigOption.from(key: "color") == .color)

        #expect(ConfigOption.from(key: "name") == .name)
        #expect(ConfigOption.from(key: "verbose") == .verbose)
        #expect(ConfigOption.from(key: "scanner") == .scanner)
        #expect(ConfigOption.from(key: "resolution") == .resolution)
        #expect(ConfigOption.from(key: "exactname") == .exactName)

        #expect(ConfigOption.from(key: "rotate") == .rotate)
        #expect(ConfigOption.from(key: "no-mrc") == .noMRC)
        #expect(ConfigOption.from(key: "mrc-resolution") == .mrcResolution)
        #expect(ConfigOption.from(key: "jpeg-quality") == .jpegQuality)
        #expect(ConfigOption.from(key: "mrc-jpeg-quality") == .mrcJpegQuality)
    }

    @Test
    func fromInvalidKeyReturnsNil() {
        #expect(ConfigOption.from(key: "invalid") == nil)
        #expect(ConfigOption.from(key: "") == nil)
        #expect(ConfigOption.from(key: "Duplex") == nil)
        #expect(ConfigOption.from(key: "help") == nil)
        #expect(ConfigOption.from(key: "flatbed") == nil)
        #expect(ConfigOption.from(key: "jpeg") == nil)
        #expect(ConfigOption.from(key: "mono") == nil)
        #expect(ConfigOption.from(key: "ocr") == nil)
    }

    @Test
    func typePropertyForFlags() {
        let flagOptions: [ConfigOption] = [
            .duplex, .batch, .verbose, .exactName, .noMRC,
        ]
        for option in flagOptions {
            #expect(option.type == .flag, "Expected \(option) to be .flag")
        }
    }

    @Test
    func typePropertyForStrings() {
        let stringOptions: [ConfigOption] = [
            .input, .format, .size, .color,
            .name, .scanner, .resolution, .rotate, .mrcResolution, .jpegQuality, .mrcJpegQuality,
        ]
        for option in stringOptions {
            #expect(option.type == .string, "Expected \(option) to be .string")
        }
    }

    @Test
    func defaultValues() {
        #expect(ConfigOption.input.defaultValue == "feeder")
        #expect(ConfigOption.format.defaultValue == "pdf")
        #expect(ConfigOption.size.defaultValue == "a4")
        #expect(ConfigOption.color.defaultValue == "color")
        #expect(ConfigOption.resolution.defaultValue == "150")

        #expect(ConfigOption.rotate.defaultValue == "0")
        #expect(ConfigOption.mrcResolution.defaultValue == "400")
        #expect(ConfigOption.jpegQuality.defaultValue == "60")
        #expect(ConfigOption.mrcJpegQuality.defaultValue == "20")
    }

    @Test
    func noDefaultValueForFlagsAndFreeformStrings() {
        let noDefaultOptions: [ConfigOption] = [
            .duplex, .batch, .verbose, .exactName, .noMRC,
            .name, .scanner,
        ]
        for option in noDefaultOptions {
            #expect(option.defaultValue == nil, "Expected \(option) to have no default")
        }
    }

    @Test
    func allCasesCount() {
        #expect(ConfigOption.allCases.count == 16)
    }

    @Test
    func shortFlagValues() {
        #expect(ConfigOption.input.shortFlag == "i")
        #expect(ConfigOption.duplex.shortFlag == "d")
        #expect(ConfigOption.batch.shortFlag == "b")
        #expect(ConfigOption.format.shortFlag == "f")
        #expect(ConfigOption.size.shortFlag == "s")
        #expect(ConfigOption.color.shortFlag == "c")
        #expect(ConfigOption.name.shortFlag == "n")
        #expect(ConfigOption.resolution.shortFlag == "r")
        #expect(ConfigOption.exactName.shortFlag == "e")
    }

    @Test
    func shortFlagNilForOptionsWithoutShortForm() {
        #expect(ConfigOption.verbose.shortFlag == nil)
        #expect(ConfigOption.scanner.shortFlag == nil)
        #expect(ConfigOption.rotate.shortFlag == nil)
        #expect(ConfigOption.noMRC.shortFlag == nil)
        #expect(ConfigOption.mrcResolution.shortFlag == nil)
        #expect(ConfigOption.jpegQuality.shortFlag == nil)
        #expect(ConfigOption.mrcJpegQuality.shortFlag == nil)
    }

    @Test
    func fromShortFlag() {
        #expect(ConfigOption.from(shortFlag: "d") == .duplex)
        #expect(ConfigOption.from(shortFlag: "f") == .format)
        #expect(ConfigOption.from(shortFlag: "r") == .resolution)
    }

    @Test
    func fromInvalidShortFlagReturnsNil() {
        #expect(ConfigOption.from(shortFlag: "x") == nil)
        #expect(ConfigOption.from(shortFlag: "z") == nil)
    }

    @Test
    func shortFlagsAreUnique() {
        var seen: [Character: ConfigOption] = [:]
        for option in ConfigOption.allCases {
            if let short = option.shortFlag {
                #expect(seen[short] == nil, "Short flag -\(short) used by both \(seen[short]!) and \(option)")
                seen[short] = option
            }
        }
    }

    @Test
    func descriptionIsNonEmpty() {
        for option in ConfigOption.allCases {
            #expect(!option.description.isEmpty, "\(option) should have a non-empty description")
        }
    }

    @Test
    func validValuesForEnumOptions() {
        #expect(ConfigOption.input.validValues != nil)
        #expect(ConfigOption.format.validValues != nil)
        #expect(ConfigOption.size.validValues != nil)
        #expect(ConfigOption.color.validValues != nil)
    }

    @Test
    func noValidValuesForFreeformStrings() {
        #expect(ConfigOption.name.validValues == nil)
        #expect(ConfigOption.scanner.validValues == nil)
        #expect(ConfigOption.resolution.validValues == nil)
        #expect(ConfigOption.rotate.validValues == nil)
        #expect(ConfigOption.mrcResolution.validValues == nil)
        #expect(ConfigOption.jpegQuality.validValues == nil)
        #expect(ConfigOption.mrcJpegQuality.validValues == nil)
    }
}
