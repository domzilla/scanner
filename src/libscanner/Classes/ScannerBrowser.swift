//
//  ScannerBrowser.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import ImageCaptureCore

// MARK: - ScannerBrowserDelegate

protocol ScannerBrowserDelegate: AnyObject {
    func scannerBrowser(_ scannerBrowser: ScannerBrowser, didFinishBrowsingWithScanner scanner: ICScannerDevice?)
    func scannerBrowser(_ scannerBrowser: ScannerBrowser, didUpdateAvailableScanners availableScanners: [String])
}

// MARK: - ScannerBrowser

class ScannerBrowser: NSObject, ICDeviceBrowserDelegate {
    let configuration: ScanConfiguration
    let deviceBrowser = ICDeviceBrowser()
    weak var delegate: ScannerBrowserDelegate?

    private(set) var selectedScanner: ICScannerDevice?
    private(set) var availableScannerNames: [String] = []
    private var searching = false

    init(configuration: ScanConfiguration) {
        self.configuration = configuration

        super.init()

        self.deviceBrowser.delegate = self
        let mask = ICDeviceTypeMask(rawValue:
            ICDeviceTypeMask.scanner.rawValue |
                ICDeviceLocationTypeMask.local.rawValue |
                ICDeviceLocationTypeMask.bonjour.rawValue |
                ICDeviceLocationTypeMask.shared.rawValue)
        self.deviceBrowser.browsedDeviceTypeMask = mask!
    }

    func browse() {
        Logger.verbose("Browsing for scanners")
        self.searching = true

        if self.configuration.flag(.list) {
            self.log("Available scanners:")
        }
        self.deviceBrowser.start()
    }

    func stopBrowsing() {
        guard self.searching else { return }
        Logger.verbose("Done searching for scanners")

        self.delegate?.scannerBrowser(self, didFinishBrowsingWithScanner: self.selectedScanner)
        self.searching = false
    }

    // MARK: - ICDeviceBrowserDelegate

    func deviceBrowser(_: ICDeviceBrowser, didAdd device: ICDevice, moreComing _: Bool) {
        Logger.verbose("Added device: \(device)")

        if self.configuration.flag(.list) {
            self.log("* \(device.name ?? "[Nameless Device]")")
        }

        guard let scannerDevice = device as? ICScannerDevice else { return }

        if let scannerName = scannerDevice.name {
            self.availableScannerNames.append(scannerName)
            self.delegate?.scannerBrowser(self, didUpdateAvailableScanners: self.availableScannerNames)
        }

        if self.deviceMatchesSpecified(device: scannerDevice) {
            self.selectedScanner = scannerDevice
            self.stopBrowsing()
        }
    }

    func deviceBrowser(_: ICDeviceBrowser, didRemove device: ICDevice, moreGoing _: Bool) {
        Logger.verbose("Removed device: \(device)")
        guard device is ICScannerDevice, let scannerName = device.name else { return }

        self.availableScannerNames.removeAll { $0 == scannerName }
        self.delegate?.scannerBrowser(self, didUpdateAvailableScanners: self.availableScannerNames)
    }

    // MARK: - Private

    private func deviceMatchesSpecified(device: ICScannerDevice) -> Bool {
        // If no name was specified, match first scanner (unless listing)
        guard let desiredName = self.configuration.string(.scanner) else {
            return !self.configuration.flag(.list)
        }
        guard let deviceName = device.name else { return false }

        // Fuzzy match: case-insensitive prefix
        if
            !self.configuration.flag(.exactName),
            deviceName.lowercased().hasPrefix(desiredName.lowercased())
        {
            return true
        }

        // Exact match
        if desiredName == deviceName {
            return true
        }

        return false
    }

    private func log(_ message: String) {
        print(message)
    }
}
