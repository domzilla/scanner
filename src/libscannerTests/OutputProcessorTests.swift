//
//  OutputProcessorTests.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 04.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Quartz
import Testing
@testable import libscanner

@Suite(.serialized)
struct OutputProcessorTests {
    // MARK: - Init

    @Test
    func initStoresProperties() {
        let url1 = URL(fileURLWithPath: "/tmp/test1.jpg")
        let url2 = URL(fileURLWithPath: "/tmp/test2.jpg")
        let config = makeConfig(["-format", "jpeg"])

        let processor = OutputProcessor(urls: [url1, url2], configuration: config)

        #expect(processor.urls.count == 2)
        #expect(processor.urls[0] == url1)
        #expect(processor.urls[1] == url2)
        #expect(processor.configuration.string(.format) == "jpeg")
    }

    // MARK: - Combine

    @Test
    func combineCreatesValidPDF() throws {
        let url1 = createTempJPEGFile()
        let url2 = createTempJPEGFile()
        let config = makeConfig([])
        let processor = OutputProcessor(urls: [url1, url2], configuration: config)

        let result = processor.combine(urls: [url1, url2])

        #expect(result != nil)
        #expect(try FileManager.default.fileExists(atPath: #require(result?.path)))
    }

    @Test
    func combineWithSinglePage() {
        let url = createTempJPEGFile()
        let config = makeConfig([])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let result = processor.combine(urls: [url])

        #expect(result != nil)
        if let result {
            let pdf = PDFDocument(url: result)
            #expect(pdf?.pageCount == 1)
        }
    }

    @Test
    func combineWithMultiplePagesHasCorrectPageCount() {
        let url1 = createTempJPEGFile()
        let url2 = createTempJPEGFile()
        let url3 = createTempJPEGFile()
        let config = makeConfig([])
        let processor = OutputProcessor(urls: [url1, url2, url3], configuration: config)

        let result = processor.combine(urls: [url1, url2, url3])

        #expect(result != nil)
        if let result {
            let pdf = PDFDocument(url: result)
            #expect(pdf?.pageCount == 3)
        }
    }

    @Test
    func combineWithEmptyURLs() {
        let config = makeConfig([])
        let processor = OutputProcessor(urls: [], configuration: config)

        let result = processor.combine(urls: [])

        #expect(result != nil)
    }

    // MARK: - Output File Extensions

    @Test
    func outputSelectsPDFExtension() {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-name", "test_pdf"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        processor.output(url: url)

        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/test_pdf.pdf"))
    }

    @Test
    func outputSelectsJPEGExtension() {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "jpeg", "-name", "test_jpg"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        processor.output(url: url)

        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/test_jpg.jpg"))
    }

    @Test
    func outputSelectsTIFFExtension() {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "tiff", "-name", "test_tif"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        processor.output(url: url)

        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/test_tif.tif"))
    }

    @Test
    func outputSelectsPNGExtension() {
        let url = createTempPNGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "png", "-name", "test_png"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        processor.output(url: url)

        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/test_png.png"))
    }

    // MARK: - File Collision Handling

    @Test
    func outputHandlesFileCollision() {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "jpeg", "-name", "collision_test"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        processor.output(url: url)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/collision_test.jpg"))

        processor.output(url: url)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/collision_test-1.jpg"))

        processor.output(url: url)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/collision_test-2.jpg"))
    }

    // MARK: - Output with Default Name

    @Test
    func outputUsesTimestampNameWhenNoNameSpecified() {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "jpeg"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        processor.output(url: url)

        let files = try? FileManager.default.contentsOfDirectory(atPath: outputDir)
        #expect(files?.count == 1)
        let filename = files?.first ?? ""
        #expect(filename.hasPrefix("scan_"))
        #expect(filename.hasSuffix(".jpg"))
    }

    // MARK: - Process Pipeline

    @Test
    func processWithJPEGFormat() async {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "jpeg", "-name", "process_jpeg"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/process_jpeg.jpg"))
    }

    @Test
    func processWithPDFFormat() async {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-name", "process_pdf"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/process_pdf.pdf"))
    }

    @Test
    func processWithMultiplePagesCombinesIntoPDF() async {
        let url1 = createTempJPEGFile()
        let url2 = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-name", "multipage"])
        let processor = OutputProcessor(urls: [url1, url2], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/multipage.pdf"))
    }

    @Test
    func processWithMultiplePagesJPEGOutputsSeparateFiles() async {
        let url1 = createTempJPEGFile()
        let url2 = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "jpeg", "-name", "multi_jpg"])
        let processor = OutputProcessor(urls: [url1, url2], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/multi_jpg.jpg"))
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/multi_jpg-1.jpg"))
    }

    @Test
    func processWithRotation() async {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "jpeg", "-name", "rotated", "-rotate", "90"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/rotated.jpg"))
    }

    @Test
    func processWithZeroRotationSkipsRotation() async {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "jpeg", "-name", "no_rotate"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/no_rotate.jpg"))
    }

    @Test
    func processWithPNGFormat() async {
        let url = createTempPNGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "png", "-name", "process_png"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/process_png.png"))
    }

    @Test
    func processWithTIFFFormat() async {
        let url = createTempJPEGFile()
        let outputDir = makeTempOutputDir()
        let config = makeConfig(["-format", "tiff", "-name", "process_tif"])
        let processor = OutputProcessor(urls: [url], configuration: config)

        let savedCwd = FileManager.default.currentDirectoryPath
        defer { FileManager.default.changeCurrentDirectoryPath(savedCwd) }
        FileManager.default.changeCurrentDirectoryPath(outputDir)

        let result = await processor.process()

        #expect(result == true)
        #expect(FileManager.default.fileExists(atPath: "\(outputDir)/process_tif.tif"))
    }
}
