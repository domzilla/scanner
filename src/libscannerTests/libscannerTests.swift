//
//  libscannerTests.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 04.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import libscanner

// MARK: - Configuration Tests

struct ConfigurationTests {
    private var testConfigPath: String {
        let tempDir = NSTemporaryDirectory()
        let path = "\(tempDir)/scannerTests_config_test.conf"
        let contents = "-duplex\n-name\nthe_name\n"
        try? contents.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test
    func loadConfigurationFromFile() {
        let config = ScanConfiguration(arguments: [], configFilePath: self.testConfigPath)

        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.flag(.flatbed) == false)
        #expect(config.string(.name) == "the_name")
    }

    @Test
    func loadConfigurationFromFileWithArgumentOverride() {
        let config = ScanConfiguration(arguments: ["-flatbed"], configFilePath: self.testConfigPath)

        #expect(config.flag(.duplex) == true)
        #expect(config.flag(.batch) == false)
        #expect(config.flag(.flatbed) == true)
        #expect(config.string(.name) == "the_name")
    }

    @Test
    func gettingTagsFromCommandLine() {
        let config = ScanConfiguration(arguments: ["taxes-2013"], configFilePath: self.testConfigPath)

        #expect(config.tags.first == "taxes-2013")
    }

    @Test
    func jpegOption() {
        let config = ScanConfiguration(arguments: ["-jpeg"])

        #expect(config.flag(.jpeg) == true)
    }

    @Test
    func jpegOptionWithJpgSynonym() {
        let config = ScanConfiguration(arguments: ["-jpg"])

        #expect(config.flag(.jpeg) == true)
    }

    @Test
    func resolutionOptionWithNonNumericalValue() {
        let config = ScanConfiguration(arguments: ["-resolution", "booger"])

        #expect(config.string(.resolution) == "booger")
        #expect(Int(config.string(.resolution) ?? "") == nil)
    }

    @Test
    func letterNotLegal() {
        let config = ScanConfiguration(arguments: ["-letter"])

        #expect(config.flag(.letter) == true)
        #expect(config.flag(.legal) == false)
    }

    @Test
    func legalNotLetter() {
        let config = ScanConfiguration(arguments: ["-legal"])

        #expect(config.flag(.letter) == false)
        #expect(config.flag(.legal) == true)
    }

    @Test
    func missingSecondParameter() {
        _ = ScanConfiguration(arguments: ["-scanner"], configFilePath: self.testConfigPath)

        let config = ScanConfiguration(arguments: ["-scanner", "epson"])
        #expect(config.string(.scanner) == "epson")
    }
}
