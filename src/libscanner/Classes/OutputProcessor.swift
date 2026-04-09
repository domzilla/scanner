//
//  OutputProcessor.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppKit
import CoreImage
import Foundation
import Quartz
import UniformTypeIdentifiers

// MARK: - OutputProcessor

class OutputProcessor: @unchecked Sendable {
    let configuration: ScanConfiguration
    let urls: [URL]

    init(urls: [URL], configuration: ScanConfiguration) {
        self.urls = urls
        self.configuration = configuration
    }

    func process() async -> Bool {
        if let rotationDegrees = Int(self.configuration.string(.rotate) ?? "0"), rotationDegrees != 0 {
            self.log("Rotating by \(rotationDegrees) degrees")
            for url in self.urls {
                if !self.rotate(imageAt: url, byDegrees: rotationDegrees) {
                    self.log("Error while rotating image")
                }
            }
        }

        let wantsPDF = self.configuration.string(.format) == "pdf"

        if !wantsPDF {
            for url in self.urls {
                self.output(url: url)
            }
        } else {
            if let combinedURL = self.combine(urls: self.urls) {
                self.output(url: combinedURL)
            } else {
                self.log("Error while creating PDF")
                return false
            }
        }

        return true
    }

    // MARK: - PDF Combining

    func combine(urls: [URL]) -> URL? {
        // Suppress CoreGraphics framework noise written to stderr during PDF operations
        self.suppressingStderr {
            if self.configuration.flag(.mrc) {
                let assembler = MRCAssembler(configuration: self.configuration)
                return assembler.assemble(urls: urls)
            }

            let document = PDFDocument()

            for url in urls {
                if let page = PDFPage(image: NSImage(byReferencing: url)) {
                    document.insert(page, at: document.pageCount)
                }
            }

            let tempFilePath = "\(NSTemporaryDirectory())/scan.pdf"
            document.write(toFile: tempFilePath)

            return URL(fileURLWithPath: tempFilePath)
        }
    }

    // MARK: - Image Rotation

    private func rotate(imageAt url: URL, byDegrees rotationDegrees: Int) -> Bool {
        guard
            let dataProvider = CGDataProvider(filename: url.path),
            let cgImage = CGImage(
                jpegDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ) else
        {
            return false
        }

        let ciImage = CIImage(cgImage: cgImage)
        let radians = CGFloat(rotationDegrees) / 180.0 * CGFloat.pi
        let rotate = CGAffineTransform(rotationAngle: radians)
        let rotatedImage = ciImage.transformed(by: rotate)
        let context = CIContext(options: nil)

        guard
            let outputImage = context.createCGImage(rotatedImage, from: rotatedImage.extent),
            let mutableData = CFDataCreateMutable(nil, 0),
            let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return false
        }

        CGImageDestinationAddImage(destination, outputImage, nil)
        if !CGImageDestinationFinalize(destination) {
            return false
        }

        do {
            try (mutableData as NSData).write(to: url)
        } catch {
            return false
        }

        return true
    }

    // MARK: - File Output

    func output(url: URL) {
        let outputDir = FileManager.default.currentDirectoryPath

        Logger.verbose("Output path: \(outputDir)")

        let ext = switch self.configuration.string(.format) {
        case "png": "png"
        case "tiff": "tif"
        case "jpeg": "jpg"
        default: "pdf"
        }

        let baseName = self.configuration.string(.name) ?? self.defaultFilename
        var destinationFilePath = "\(outputDir)/\(baseName).\(ext)"
        var collisionIndex = 1
        while FileManager.default.fileExists(atPath: destinationFilePath) {
            destinationFilePath = "\(outputDir)/\(baseName)-\(collisionIndex).\(ext)"
            collisionIndex += 1
        }

        Logger.verbose("About to copy \(url.absoluteString) to \(destinationFilePath)")

        let destinationURL = URL(fileURLWithPath: destinationFilePath)
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
        } catch {
            self.log("Error while copying file to \(destinationURL.absoluteString)")
            return
        }

        self.log("Saved to \(destinationFilePath)")
    }

    // MARK: - Helpers

    private func suppressingStderr<T>(_ body: () -> T) -> T {
        let originalStderr = dup(STDERR_FILENO)
        let devNull = open("/dev/null", O_WRONLY)
        dup2(devNull, STDERR_FILENO)
        close(devNull)
        let result = body()
        dup2(originalStderr, STDERR_FILENO)
        close(originalStderr)
        return result
    }

    private var defaultFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "scan_\(formatter.string(from: Date()))"
    }

    private func log(_ message: String) {
        print(message)
    }
}
