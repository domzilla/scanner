//
//  AppControllerTests.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 09.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import libscanner

@Suite(.serialized)
struct AppControllerTests {
    // MARK: - resolveDebugInput

    @Test
    func resolveDebugInputReturnsSingleFile() {
        let file = createTempJPEGFile()

        let result = AppController.resolveDebugInput(path: file.path)

        guard case let .success(urls) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(urls.count == 1)
        #expect(urls.first?.lastPathComponent == file.lastPathComponent)
    }

    @Test
    func resolveDebugInputExpandsDirectoryInSortedOrder() {
        let dir = makeTempOutputDir()
        // Create out-of-order filenames to prove the resolver sorts them.
        let b = "\(dir)/b.jpg"
        let a = "\(dir)/a.jpg"
        let c = "\(dir)/c.jpg"
        for path in [b, a, c] {
            try? FileManager.default.copyItem(atPath: createTempJPEGFile().path, toPath: path)
        }

        let result = AppController.resolveDebugInput(path: dir)

        guard case let .success(urls) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(urls.map(\.lastPathComponent) == ["a.jpg", "b.jpg", "c.jpg"])
    }

    @Test
    func resolveDebugInputIgnoresNonImageFilesInDirectory() {
        let dir = makeTempOutputDir()
        try? FileManager.default.copyItem(atPath: createTempJPEGFile().path, toPath: "\(dir)/page.jpg")
        try? "text".write(toFile: "\(dir)/notes.txt", atomically: true, encoding: .utf8)
        try? "data".write(toFile: "\(dir)/archive.zip", atomically: true, encoding: .utf8)

        let result = AppController.resolveDebugInput(path: dir)

        guard case let .success(urls) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(urls.count == 1)
        #expect(urls.first?.lastPathComponent == "page.jpg")
    }

    @Test
    func resolveDebugInputAcceptsAllSupportedExtensions() {
        let dir = makeTempOutputDir()
        let jpegSource = createTempJPEGFile()
        let pngSource = createTempPNGFile()
        // Reuse the real image files as stand-ins for all supported extensions.
        // The resolver filters purely by extension, not by file magic.
        for name in ["one.jpg", "two.jpeg", "three.tif", "four.tiff"] {
            try? FileManager.default.copyItem(atPath: jpegSource.path, toPath: "\(dir)/\(name)")
        }
        try? FileManager.default.copyItem(atPath: pngSource.path, toPath: "\(dir)/five.png")

        let result = AppController.resolveDebugInput(path: dir)

        guard case let .success(urls) = result else {
            Issue.record("expected success, got \(result)")
            return
        }
        #expect(urls.count == 5)
    }

    @Test
    func resolveDebugInputFailsForMissingPath() {
        let result = AppController.resolveDebugInput(path: "/tmp/scanner-tests-does-not-exist-\(UUID().uuidString)")

        guard case let .failure(message) = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
        #expect(message.contains("does not exist"))
    }

    @Test
    func resolveDebugInputFailsForEmptyDirectory() {
        let dir = makeTempOutputDir()

        let result = AppController.resolveDebugInput(path: dir)

        guard case let .failure(message) = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
        #expect(message.contains("no image files found"))
    }

    // MARK: - stageDebugInput

    @Test
    func stageDebugInputCopiesToFreshTempDirAndPreservesOrder() throws {
        let first = createTempJPEGFile()
        let second = createTempJPEGFile()
        let third = createTempJPEGFile()

        let staged = try AppController.stageDebugInput([first, second, third])

        #expect(staged.count == 3)
        for url in staged {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
        #expect(staged[0].lastPathComponent == "page-001.jpg")
        #expect(staged[1].lastPathComponent == "page-002.jpg")
        #expect(staged[2].lastPathComponent == "page-003.jpg")
        // All staged files must live under the same temp staging directory.
        let parents = Set(staged.map { $0.deletingLastPathComponent().path })
        #expect(parents.count == 1)
    }

    @Test
    func stageDebugInputDoesNotMutateOriginals() throws {
        let original = createTempJPEGFile()
        let originalSize = try FileManager.default.attributesOfItem(atPath: original.path)[.size] as? Int

        _ = try AppController.stageDebugInput([original])

        #expect(FileManager.default.fileExists(atPath: original.path))
        let afterSize = try FileManager.default.attributesOfItem(atPath: original.path)[.size] as? Int
        #expect(originalSize == afterSize)
    }
}
