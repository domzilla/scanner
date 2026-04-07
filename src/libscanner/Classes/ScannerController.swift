//
//  ScannerController.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import ImageCaptureCore
import UniformTypeIdentifiers

// MARK: - ScannerControllerDelegate

protocol ScannerControllerDelegate: AnyObject {
    func scannerControllerDidFail(_ scannerController: ScannerController)
    func scannerControllerDidSucceed(_ scannerController: ScannerController)
    func scannerController(_ scannerController: ScannerController, didObtainResolutions resolutions: IndexSet)
}

// MARK: - ScannerController

class ScannerController: NSObject, @unchecked Sendable, ICScannerDeviceDelegate {
    let scanner: ICScannerDevice
    let configuration: ScanConfiguration
    weak var delegate: ScannerControllerDelegate?

    private var scannedURLs: [URL] = []
    private var pendingAction: PendingAction = .scan

    private var desiredFunctionalUnitType: ICScannerFunctionalUnitType {
        self.configuration.string(.input) == "flatbed" ? .flatbed : .documentFeeder
    }

    init(scanner: ICScannerDevice, configuration: ScanConfiguration) {
        self.scanner = scanner
        self.configuration = configuration

        super.init()

        self.scanner.delegate = self
    }

    func scan() {
        Logger.verbose("Opening session with scanner")
        self.scanner.requestOpenSession()
    }

    func getSupportedResolutions() {
        guard self.scanner.hasOpenSession else {
            self.scanner.requestOpenSession()
            return
        }
        self.obtainResolutions()
    }

    // MARK: - ICScannerDeviceDelegate

    func device(_: ICDevice, didEncounterError error: Error?) {
        Logger.verbose("didEncounterError: \(error?.localizedDescription ?? "[no error]")")
        self.delegate?.scannerControllerDidFail(self)
    }

    func device(_: ICDevice, didCloseSessionWithError error: Error?) {
        Logger.verbose("didCloseSessionWithError: \(error?.localizedDescription ?? "[no error]")")
        self.delegate?.scannerControllerDidFail(self)
    }

    func device(_: ICDevice, didOpenSessionWithError error: Error?) {
        Logger.verbose("didOpenSessionWithError: \(error?.localizedDescription ?? "[no error]")")

        guard error == nil else {
            self.log("Error received while attempting to open a session with the scanner.")
            self.delegate?.scannerControllerDidFail(self)
            return
        }
    }

    func didRemove(_: ICDevice) {}

    func deviceDidBecomeReady(_: ICDevice) {
        Logger.verbose("deviceDidBecomeReady")

        switch self.pendingAction {
        case .none:
            break
        case .obtainResolutions:
            self.obtainResolutions()
        case .scan:
            self.selectFunctionalUnit()
        }
    }

    func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        Logger
            .verbose("didSelectFunctionalUnit: \(functionalUnit) error: \(error?.localizedDescription ?? "[no error]")")

        // NOTE: Despite not being optional, functionalUnit can arrive as nil at runtime.
        // In release builds, checking a non-optional for nil always returns false,
        // so we check its address instead.
        let address = unsafeBitCast(functionalUnit, to: Int.self)
        if address != 0x0, functionalUnit.type == self.desiredFunctionalUnitType {
            self.configureScanner()
            self.log("Starting scan...")
            scanner.requestScan()
        }
    }

    func scannerDevice(_: ICScannerDevice, didScanTo url: URL) {
        Logger.verbose("didScanTo \(url)")
        self.scannedURLs.append(url)
    }

    func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
        Logger.verbose("didCompleteScanWithError \(error?.localizedDescription ?? "[no error]")")

        guard error == nil else {
            self.log("ERROR: \(error!.localizedDescription)")
            self.delegate?.scannerControllerDidFail(self)
            return
        }

        if self.configuration.flag(.batch) {
            self.log("Press RETURN to scan next page or S to stop")
            let userInput = String(format: "%c", getchar())
            if !"sS".contains(userInput) {
                Logger.verbose("Continuing scan")
                scanner.requestScan()
                return
            }
        }

        guard !self.scannedURLs.isEmpty else {
            self.log("No pages were scanned.")
            self.delegate?.scannerControllerDidFail(self)
            return
        }

        let outputProcessor = OutputProcessor(
            urls: self.scannedURLs,
            configuration: self.configuration
        )

        Task {
            let succeeded = await outputProcessor.process()
            if succeeded {
                self.delegate?.scannerControllerDidSucceed(self)
            } else {
                self.delegate?.scannerControllerDidFail(self)
            }
        }
    }

    // MARK: - Private

    private enum PendingAction {
        case none, obtainResolutions, scan
    }

    private func obtainResolutions() {
        self.delegate?.scannerController(
            self,
            didObtainResolutions: self.scanner.selectedFunctionalUnit.supportedResolutions
        )
    }

    private func selectFunctionalUnit() {
        self.scanner.requestSelect(self.desiredFunctionalUnitType)
    }

    private func configureScanner() {
        Logger.verbose("Configuring scanner")

        let functionalUnit = self.scanner.selectedFunctionalUnit

        if functionalUnit.type == .documentFeeder {
            self.configureDocumentFeeder()
        } else {
            self.configureFlatbed()
        }

        let desiredResolution = Int(self.configuration.string(.resolution) ?? "150") ?? 150
        if let resolutionIndex = functionalUnit.supportedResolutions.integerGreaterThanOrEqualTo(desiredResolution) {
            functionalUnit.resolution = resolutionIndex
        }

        if self.configuration.string(.color) == "mono" {
            functionalUnit.pixelDataType = .BW
            functionalUnit.bitDepth = .depth1Bit
        } else {
            functionalUnit.pixelDataType = .RGB
            functionalUnit.bitDepth = .depth8Bits
        }

        self.scanner.transferMode = .fileBased
        self.scanner.downloadsDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        self.scanner.documentName = "Scan"

        switch self.configuration.string(.format) {
        case "png":
            self.scanner.documentUTI = UTType.png.identifier
        case "tiff":
            self.scanner.documentUTI = UTType.tiff.identifier
        default:
            self.scanner.documentUTI = UTType.jpeg.identifier
        }
    }

    private func configureDocumentFeeder() {
        Logger.verbose("Configuring Document Feeder")

        guard let functionalUnit = self.scanner.selectedFunctionalUnit as? ICScannerFunctionalUnitDocumentFeeder else { return }

        switch self.configuration.string(.size) {
        case "letter":
            functionalUnit.documentType = .typeUSLetter
        case "legal":
            functionalUnit.documentType = .typeUSLegal
        default:
            functionalUnit.documentType = .typeA4
        }

        functionalUnit.duplexScanningEnabled = self.configuration.flag(.duplex)
    }

    private func configureFlatbed() {
        Logger.verbose("Configuring Flatbed")

        guard let functionalUnit = self.scanner.selectedFunctionalUnit as? ICScannerFunctionalUnitFlatbed else { return }

        functionalUnit.measurementUnit = .inches
        let physicalSize = functionalUnit.physicalSize
        functionalUnit.scanArea = NSRect(x: 0, y: 0, width: physicalSize.width, height: physicalSize.height)
    }

    private func log(_ message: String) {
        if self.configuration.flag(.ocr) {
            fputs("\(message)\n", stderr)
        } else {
            print(message)
        }
    }
}

// MARK: - IndexSet Extension

extension IndexSet {
    fileprivate func integerGreaterThanOrEqualTo(_ value: Int) -> Int? {
        if self.contains(value) {
            return value
        }
        return self.integerGreaterThan(value)
    }
}
