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
        #expect(ConfigOption.from(key: "list") == .list)
        #expect(ConfigOption.from(key: "format") == .format)
        #expect(ConfigOption.from(key: "size") == .size)
        #expect(ConfigOption.from(key: "color") == .color)
        #expect(ConfigOption.from(key: "open") == .open)
        #expect(ConfigOption.from(key: "name") == .name)
        #expect(ConfigOption.from(key: "verbose") == .verbose)
        #expect(ConfigOption.from(key: "scanner") == .scanner)
        #expect(ConfigOption.from(key: "resolution") == .resolution)
        #expect(ConfigOption.from(key: "browsesecs") == .browseSecs)
        #expect(ConfigOption.from(key: "exactname") == .exactName)

        #expect(ConfigOption.from(key: "rotate") == .rotate)
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
            .duplex, .batch, .list, .open, .verbose, .exactName,
        ]
        for option in flagOptions {
            #expect(option.type == .flag, "Expected \(option) to be .flag")
        }
    }

    @Test
    func typePropertyForStrings() {
        let stringOptions: [ConfigOption] = [
            .input, .format, .size, .color,
            .name, .scanner, .resolution, .browseSecs, .rotate,
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
        #expect(ConfigOption.browseSecs.defaultValue == "10")
        #expect(ConfigOption.rotate.defaultValue == "0")
    }

    @Test
    func noDefaultValueForFlagsAndFreeformStrings() {
        let noDefaultOptions: [ConfigOption] = [
            .duplex, .batch, .list, .open, .verbose, .exactName,
            .name, .scanner,
        ]
        for option in noDefaultOptions {
            #expect(option.defaultValue == nil, "Expected \(option) to have no default")
        }
    }

    @Test
    func allCasesCount() {
        #expect(ConfigOption.allCases.count == 15)
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
        #expect(ConfigOption.browseSecs.validValues == nil)
        #expect(ConfigOption.rotate.validValues == nil)
    }
}
