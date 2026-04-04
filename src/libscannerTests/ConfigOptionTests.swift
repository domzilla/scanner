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
        #expect(ConfigOption.from(key: "duplex") == .duplex)
        #expect(ConfigOption.from(key: "batch") == .batch)
        #expect(ConfigOption.from(key: "list") == .list)
        #expect(ConfigOption.from(key: "flatbed") == .flatbed)
        #expect(ConfigOption.from(key: "jpeg") == .jpeg)
        #expect(ConfigOption.from(key: "tiff") == .tiff)
        #expect(ConfigOption.from(key: "png") == .png)
        #expect(ConfigOption.from(key: "legal") == .legal)
        #expect(ConfigOption.from(key: "letter") == .letter)
        #expect(ConfigOption.from(key: "a4") == .a4)
        #expect(ConfigOption.from(key: "mono") == .mono)
        #expect(ConfigOption.from(key: "open") == .open)
        #expect(ConfigOption.from(key: "name") == .name)
        #expect(ConfigOption.from(key: "verbose") == .verbose)
        #expect(ConfigOption.from(key: "scanner") == .scanner)
        #expect(ConfigOption.from(key: "resolution") == .resolution)
        #expect(ConfigOption.from(key: "browsesecs") == .browseSecs)
        #expect(ConfigOption.from(key: "exactname") == .exactName)
        #expect(ConfigOption.from(key: "ocr") == .ocr)
        #expect(ConfigOption.from(key: "rotate") == .rotate)
    }

    @Test
    func fromAllSynonyms() {
        #expect(ConfigOption.from(key: "dup") == .duplex)
        #expect(ConfigOption.from(key: "fb") == .flatbed)
        #expect(ConfigOption.from(key: "jpg") == .jpeg)
        #expect(ConfigOption.from(key: "tif") == .tiff)
        #expect(ConfigOption.from(key: "bw") == .mono)
        #expect(ConfigOption.from(key: "v") == .verbose)
        #expect(ConfigOption.from(key: "s") == .scanner)
        #expect(ConfigOption.from(key: "res") == .resolution)
        #expect(ConfigOption.from(key: "minResolution") == .resolution)
        #expect(ConfigOption.from(key: "time") == .browseSecs)
        #expect(ConfigOption.from(key: "t") == .browseSecs)
        #expect(ConfigOption.from(key: "exact") == .exactName)
    }

    @Test
    func fromInvalidKeyReturnsNil() {
        #expect(ConfigOption.from(key: "invalid") == nil)
        #expect(ConfigOption.from(key: "") == nil)
        #expect(ConfigOption.from(key: "Duplex") == nil)
        #expect(ConfigOption.from(key: "JPEG") == nil)
        #expect(ConfigOption.from(key: "help") == nil)
    }

    @Test
    func typePropertyForFlags() {
        let flagOptions: [ConfigOption] = [
            .duplex, .batch, .list, .flatbed, .jpeg, .tiff, .png,
            .legal, .letter, .a4, .mono, .open, .verbose, .exactName, .ocr,
        ]
        for option in flagOptions {
            #expect(option.type == .flag, "Expected \(option) to be .flag")
        }
    }

    @Test
    func typePropertyForStrings() {
        let stringOptions: [ConfigOption] = [
            .name, .scanner, .resolution, .browseSecs, .rotate,
        ]
        for option in stringOptions {
            #expect(option.type == .string, "Expected \(option) to be .string")
        }
    }

    @Test
    func defaultValues() {
        #expect(ConfigOption.resolution.defaultValue == "150")
        #expect(ConfigOption.browseSecs.defaultValue == "10")
        #expect(ConfigOption.rotate.defaultValue == "0")
    }

    @Test
    func noDefaultValueForFlagsAndOtherStrings() {
        let noDefaultOptions: [ConfigOption] = [
            .duplex, .batch, .list, .flatbed, .jpeg, .tiff, .png,
            .legal, .letter, .a4, .mono, .open, .verbose, .exactName, .ocr,
            .name, .scanner,
        ]
        for option in noDefaultOptions {
            #expect(option.defaultValue == nil, "Expected \(option) to have no default")
        }
    }

    @Test
    func allCasesCount() {
        #expect(ConfigOption.allCases.count == 20)
    }

    @Test
    func descriptionIsNonEmpty() {
        for option in ConfigOption.allCases {
            #expect(!option.description.isEmpty, "\(option) should have a non-empty description")
        }
    }

    @Test
    func synonymsForOptionsWithoutSynonyms() {
        let noSynonymOptions: [ConfigOption] = [
            .batch, .list, .png, .legal, .letter, .a4, .open, .name, .ocr, .rotate,
        ]
        for option in noSynonymOptions {
            #expect(option.synonyms.isEmpty, "\(option) should have no synonyms")
        }
    }
}
