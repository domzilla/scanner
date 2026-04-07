//
//  AppController.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation
import ImageCaptureCore

// MARK: - ExitCode

enum ExitCode: Int32 {
    case success = 0
    case failure = 1
}

// MARK: - AppController

public class AppController: NSObject {
    let configuration: ScanConfiguration
    var scannerBrowserTimer: Timer?
    var scannerController: ScannerController?

    private let scannerBrowser: ScannerBrowser

    public init(arguments: [String]) {
        self.configuration = ScanConfiguration(arguments: Array(arguments.dropFirst()))
        self.scannerBrowser = ScannerBrowser(configuration: self.configuration)

        super.init()

        Logger.configuration = self.configuration
        self.scannerBrowser.delegate = self
    }

    public func go() {
        self.scannerBrowser.browse()

        let timerExpiration = Double(self.configuration.string(.browseSecs) ?? "10") ?? 10.0
        self.scannerBrowserTimer = Timer
            .scheduledTimer(withTimeInterval: timerExpiration, repeats: false) { [weak self] _ in
                self?.scannerBrowser.stopBrowsing()
            }

        Logger.verbose("Waiting up to \(timerExpiration) seconds to find scanners")
    }

    func exit(with code: ExitCode = .success) {
        self.log("Done")
        DispatchQueue.main.async {
            CFRunLoopStop(CFRunLoopGetCurrent())
            Darwin.exit(code.rawValue)
        }
    }

    func scan(scanner: ICScannerDevice) {
        self.scannerController = ScannerController(scanner: scanner, configuration: self.configuration)
        self.scannerController?.delegate = self
        self.scannerController?.scan()
    }

    private func log(_ message: String) {
        print(message)
    }
}

// MARK: - ScannerBrowserDelegate

extension AppController: ScannerBrowserDelegate {
    func scannerBrowser(_: ScannerBrowser, didFinishBrowsingWithScanner scanner: ICScannerDevice?) {
        Logger.verbose("Found scanner: \(scanner?.name ?? "[nil]")")
        self.scannerBrowserTimer?.invalidate()
        self.scannerBrowserTimer = nil

        guard !self.configuration.flag(.list) else {
            self.exit(with: .success)
            return
        }

        guard let scanner else {
            self.log("No scanner was found.")
            self.exit(with: .failure)
            return
        }

        self.scan(scanner: scanner)
    }

    func scannerBrowser(_: ScannerBrowser, didUpdateAvailableScanners _: [String]) {
        // No-op
    }
}

// MARK: - ScannerControllerDelegate

extension AppController: ScannerControllerDelegate {
    func scannerController(_: ScannerController, didObtainResolutions _: IndexSet) {
        // No-op
    }

    func scannerControllerDidFail(_: ScannerController) {
        self.log("Failed to scan document.")
        self.exit(with: .failure)
    }

    func scannerControllerDidSucceed(_: ScannerController) {
        self.exit(with: .success)
    }
}
