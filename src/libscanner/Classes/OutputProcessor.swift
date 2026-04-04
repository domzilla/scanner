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
import FoundationModels
import Quartz
import UniformTypeIdentifiers
import Vision

// MARK: - OutputProcessor

class OutputProcessor: @unchecked Sendable {
    let configuration: ScanConfiguration
    let urls: [URL]
    private var summaries: [URL: String] = [:]

    init(urls: [URL], configuration: ScanConfiguration) {
        self.urls = urls
        self.configuration = configuration
    }

    func process() async -> Bool {
        let wantsOCROutput = self.configuration.flag(.ocr)
        let wantsSummary = self.configuration.flag(.summarize)
        let wantsAutoname = self.configuration.flag(.autoname)

        let needsOCR = wantsOCROutput || wantsSummary || wantsAutoname
        var fullText = ""
        if needsOCR {
            for url in self.urls {
                let pageText = await self.extractText(fromImageAt: url)
                if wantsOCROutput {
                    print(pageText)
                }
                fullText += pageText
            }
        }

        if let rotationDegrees = Int(self.configuration.string(.rotate) ?? "0"), rotationDegrees != 0 {
            self.log("Rotating by \(rotationDegrees) degrees")
            for url in self.urls {
                if !self.rotate(imageAt: url, byDegrees: rotationDegrees) {
                    self.log("Error while rotating image")
                }
            }
        }

        let wantsPDF = !self.configuration.flag(.jpeg) &&
            !self.configuration.flag(.tiff) &&
            !self.configuration.flag(.png)

        if !wantsPDF {
            for url in self.urls {
                await self.handleAI(for: url, withFullText: fullText)
                self.outputAndTag(url: url)
            }
        } else {
            if let combinedURL = self.combine(urls: self.urls) {
                await self.handleAI(for: combinedURL, withFullText: fullText)
                self.outputAndTag(url: combinedURL)
            } else {
                self.log("Error while creating PDF")
                return false
            }
        }

        return true
    }

    // MARK: - PDF Combining

    func combine(urls: [URL]) -> URL? {
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

    // MARK: - OCR

    private func extractText(fromImageAt imageURL: URL) async -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate

        do {
            let observations = try await request.perform(on: imageURL)
            let strings = observations.map { $0.topCandidates(1).first?.string ?? "" }
            return strings.joined(separator: "\n")
        } catch {
            self.log("Error while performing text recognition")
            return ""
        }
    }

    // MARK: - AI Processing

    private func handleAI(for url: URL, withFullText fullText: String) async {
        let wantsSummary = self.configuration.flag(.summarize)
        let wantsAutoname = self.configuration.flag(.autoname)

        if wantsSummary {
            if let summaryText = await self.summarize(fullText) {
                Logger.verbose("Summary: \(summaryText)")
                self.summaries[url] = summaryText
            }
        }

        if wantsAutoname, self.configuration.string(.name) == nil {
            let filename = await self.autoName(for: fullText, tags: self.configuration.tags)
            Logger.verbose("Autonaming to \(filename)")
            // NOTE: Since ScanConfiguration is now immutable, we store the autoname
            // result and use it in outputAndTag via a local override.
            self.autonameResult = filename
        }
    }

    private var autonameResult: String?

    private func autoName(for text: String, tags: [String]) async -> String {
        if #available(macOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                self.log("Unable to autoname because language model is not available")
                return ""
            }

            let session = LanguageModelSession()
            let prompt = """
            The following document was scanned by a user who would like you to generate an appropriate name for the scanned file based on its content.
            The user has assigned the following tags to the document, which might be helpful in naming: \(tags
                .joined(separator: ","))

            Please respond with a filename that meets the following criteria:
            - It has no special characters or spaces (use dashes instead). It must be a valid macOS filename.
            - It captures what the document is about (e.g. "mortgage-statement-2025-07", "legal-settlement", "jenny-divorce-final")
            - If an appropriate name cannot be determined, return "scan"
            - If you can identify the organization it's from (e.g. Fidelity, DMV, IRS, etc.), put that in the filename
            - Keep names short. Prefer "Fidelity" over "Fidelity Investments"
            - Don't over-index on the tags - they should only inform your name, not dictate it
            - Do not include a date in the filename
            - Do not append a file type suffix
            - Do not return any other commentary or context -- only reply with the filename itself

            The user's document follows:
            \(text)
            """.prefix(10000)

            do {
                let response = try await session.respond(to: String(prompt))
                let proposedFilename = response.content
                if proposedFilename == "scan" {
                    return self.defaultFilename
                }
                if self.isValidMacOSFilename(proposedFilename) {
                    return proposedFilename
                }
            } catch {
                self.log("Error while auto naming: \(error)")
            }
        } else {
            self.log("Unable to auto name because this version of macOS does not have Apple Intelligence")
        }

        return self.defaultFilename
    }

    private func summarize(_ text: String) async -> String? {
        if #available(macOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                self.log("Unable to summarize because language model is not available")
                return ""
            }

            let session = LanguageModelSession()
            let prompt = """
            The following document was scanned by a user who would now like a summary.
            Please respond with a summary of the document and no other content.
            Do not prefix with "Document Summary" or "This document" or anything like that. Just give the summary itself with no intro.
            Your summary should make it clear what this document is, any key details, and any key terms (names, places, companies) that might be useful in search.
            Try to avoid including sensitive content in your summary (e.g. SSN, phone numbers, etc.)

            The user's document follows:
            \(text)
            """.prefix(10000)

            do {
                let response = try await session.respond(to: String(prompt))
                return response.content
            } catch {
                self.log("Error while summarizing: \(error)")
            }
        } else {
            self.log("Unable to summarize because this version of macOS does not have Apple Intelligence")
        }

        return nil
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

    // MARK: - File Output & Tagging

    func outputAndTag(url: URL) {
        let calendar = Calendar(identifier: .gregorian)
        let dateComponents = calendar.dateComponents([.year, .hour, .minute, .second], from: Date())

        guard let outputRootDirectory = self.configuration.string(.dir) else { return }
        var path = outputRootDirectory

        if !self.configuration.tags.isEmpty {
            let year = dateComponents.year.map(String.init) ?? ""
            path = "\(path)/\(self.configuration.tags[0])/\(year)"
        }

        Logger.verbose("Output path: \(path)")

        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            self.log("Error while creating directory \(path)")
            return
        }

        let destinationFileExtension = if self.configuration.flag(.png) {
            "png"
        } else if self.configuration.flag(.tiff) {
            "tif"
        } else if self.configuration.flag(.jpeg) {
            "jpg"
        } else {
            "pdf"
        }

        let resolvedFilename = self.configuration.string(.name) ?? self.autonameResult ?? self.defaultFilename
        let destinationFileRoot = "\(path)/\(resolvedFilename)"

        var destinationFilePath = "\(destinationFileRoot).\(destinationFileExtension)"
        var collisionIndex = 0
        while FileManager.default.fileExists(atPath: destinationFilePath) {
            destinationFilePath = "\(destinationFileRoot).\(collisionIndex).\(destinationFileExtension)"
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

        // Alias to all other tag locations
        if self.configuration.tags.count > 1 {
            let year = dateComponents.year.map(String.init) ?? ""
            for tag in self.configuration.tags.dropFirst() {
                Logger.verbose("Aliasing to tag \(tag)")
                let aliasDirPath = "\(outputRootDirectory)/\(tag)/\(year)"
                do {
                    try FileManager.default.createDirectory(
                        atPath: aliasDirPath,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                } catch {
                    self.log("Error while creating directory \(aliasDirPath)")
                    return
                }

                let aliasFileRoot = "\(aliasDirPath)/\(resolvedFilename)"
                var aliasFilePath = "\(aliasFileRoot).\(destinationFileExtension)"
                var aliasCollisionIndex = 0
                while FileManager.default.fileExists(atPath: aliasFilePath) {
                    aliasFilePath = "\(aliasFileRoot).\(aliasCollisionIndex).\(destinationFileExtension)"
                    aliasCollisionIndex += 1
                }

                Logger.verbose("Aliasing to \(aliasFilePath)")
                do {
                    try FileManager.default.createSymbolicLink(
                        atPath: aliasFilePath,
                        withDestinationPath: destinationFilePath
                    )
                } catch {
                    self.log("Error while creating alias at \(aliasFilePath)")
                    return
                }
            }
        }

        // Write summary file
        if self.configuration.flag(.summarize), let summaryText = self.summaries[url] {
            var summaryFilePath = "\(destinationFileRoot).summary.txt"
            var summaryCollisionIndex = 0
            while FileManager.default.fileExists(atPath: summaryFilePath) {
                summaryFilePath = "\(destinationFileRoot).\(summaryCollisionIndex).summary.txt"
                summaryCollisionIndex += 1
            }

            Logger.verbose("About to write summary to \(summaryFilePath)")

            do {
                try summaryText.write(toFile: summaryFilePath, atomically: true, encoding: .utf8)
            } catch {
                self.log("Error while writing summary \(summaryFilePath)")
            }
        }

        // Open file if requested
        if self.configuration.flag(.open) {
            Logger.verbose("Opening file at \(destinationFilePath)")
            NSWorkspace.shared.open(URL(fileURLWithPath: destinationFilePath))
        }
    }

    // MARK: - Helpers

    private var defaultFilename: String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let hour = String(format: "%02d", components.hour ?? 0)
        let minute = String(format: "%02d", components.minute ?? 0)
        let second = String(format: "%02d", components.second ?? 0)
        return "scan_\(hour)\(minute)\(second)"
    }

    private func isValidMacOSFilename(_ filename: String) -> Bool {
        guard !filename.isEmpty else { return false }
        guard filename != ".", filename != ".." else { return false }
        if filename.contains(":") || filename.contains("\u{0000}") {
            return false
        }
        if filename.lengthOfBytes(using: .utf8) > 255 {
            return false
        }
        return true
    }

    private func log(_ message: String) {
        if self.configuration.flag(.ocr) {
            fputs("\(message)\n", stderr)
        } else {
            print(message)
        }
    }
}
