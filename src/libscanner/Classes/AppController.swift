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

public class AppController: NSObject, @unchecked Sendable {
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
        // Debug input: bypass the hardware scanner entirely and feed the given path
        // straight into the output pipeline. See --debug-input in ScanConfiguration.
        if let path = self.configuration.string(.debugInput) {
            self.runDebugInput(path: path)
            return
        }

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

    // MARK: - Debug Input

    /// Runs the output pipeline against a user-supplied path instead of scanning.
    /// Validates the path, expands directory inputs, copies files to a temp location
    /// so that `--rotate` does not mutate the originals, and then hands the staged
    /// URLs to `OutputProcessor` exactly like a real scan would.
    private func runDebugInput(path: String) {
        guard self.options.mode == .scan else {
            self.log("--debug-input cannot be used with 'scanner list'")
            self.exit(with: .failure)
            return
        }

        let resolved: [URL]
        switch Self.resolveDebugInput(path: path) {
        case let .success(urls):
            resolved = urls
        case let .failure(message):
            self.log("--debug-input: \(message)")
            self.exit(with: .failure)
            return
        }
        Logger.verbose("debug-input: resolved \(resolved.count) page(s) from \(path)")

        let staged: [URL]
        do {
            staged = try Self.stageDebugInput(resolved)
        } catch {
            self.log("--debug-input: failed to stage inputs: \(error.localizedDescription)")
            self.exit(with: .failure)
            return
        }

        let outputProcessor = OutputProcessor(urls: staged, configuration: self.configuration)
        Task {
            let succeeded = await outputProcessor.process()
            self.exit(with: succeeded ? .success : .failure)
        }
    }

    /// Result of resolving a `--debug-input` path into a list of input URLs.
    enum DebugInputResolution: Equatable {
        case success([URL])
        case failure(String)
    }

    /// Supported image extensions for directory-mode `--debug-input`.
    static let debugInputAllowedExtensions: Set<String> = ["jpg", "jpeg", "png", "tif", "tiff"]

    /// Expands a `--debug-input` path into the concrete list of image URLs to feed
    /// into the pipeline. File paths become single-element lists; directories become
    /// the lexicographically-sorted list of image files contained directly within
    /// them. Non-existent paths and empty directories return failure messages that
    /// are suitable for user-facing logging.
    static func resolveDebugInput(path: String) -> DebugInputResolution {
        let fileManager = FileManager.default
        let expanded = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory) else {
            return .failure("path does not exist: \(expanded)")
        }

        if isDirectory.boolValue {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: expanded) else {
                return .failure("cannot read directory: \(expanded)")
            }
            let urls = contents
                .filter { self.debugInputAllowedExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
                .sorted()
                .map { URL(fileURLWithPath: "\(expanded)/\($0)") }
            if urls.isEmpty {
                return .failure("no image files found in \(expanded)")
            }
            return .success(urls)
        }
        return .success([URL(fileURLWithPath: expanded)])
    }

    /// Copies the given input URLs into a fresh temp directory so that downstream
    /// steps (notably `--rotate`, which writes back to the input file path) can
    /// operate without mutating the user's originals. Staged files are renamed to
    /// `page-NNN.<ext>` so the lexicographic ordering from `resolveDebugInput` is
    /// preserved across the staging copy.
    static func stageDebugInput(_ urls: [URL]) throws -> [URL] {
        let fileManager = FileManager.default
        let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("scanner-debug-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        var staged: [URL] = []
        staged.reserveCapacity(urls.count)
        for (index, source) in urls.enumerated() {
            let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension
            let destination = stagingDir.appendingPathComponent(
                String(format: "page-%03d.%@", index + 1, ext)
            )
            try fileManager.copyItem(at: source, to: destination)
            staged.append(destination)
        }
        return staged
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
