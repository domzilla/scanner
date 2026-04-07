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
    let options: AppOptions
    let configuration: ScanConfiguration
    var scannerBrowserTimer: Timer?
    var scannerController: ScannerController?

    private let scannerBrowser: ScannerBrowser

    public init(options: AppOptions, configuration: ScanConfiguration) {
        self.options = options
        self.configuration = configuration
        self.scannerBrowser = ScannerBrowser(options: options, configuration: self.configuration)

        super.init()

        Logger.configuration = self.configuration
        self.scannerBrowser.delegate = self
    }

    public func go() {
        self.scannerBrowser.browse()

        self.scannerBrowserTimer = Timer
            .scheduledTimer(withTimeInterval: self.options.timeout, repeats: false) { [weak self] _ in
                self?.scannerBrowser.stopBrowsing()
            }

        Logger.verbose("Waiting up to \(self.options.timeout) seconds to find scanners")
    }

    func exit(with code: ExitCode = .success) {
        if code == .success {
            self.log("Done")
        }
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

        guard self.options.mode != .list else {
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
        self.exit(with: .failure)
    }

    func scannerControllerDidSucceed(_: ScannerController) {
        self.exit(with: .success)
    }
}
