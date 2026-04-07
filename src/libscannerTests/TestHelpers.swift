//
//  TestHelpers.swift
//  libscannerTests
//
//  Created by Dominic Rodemer on 04.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppKit
import Foundation
@testable import libscanner

func makeConfig(_ args: [String], configFile: String? = nil) throws -> ScanConfiguration {
    try ScanConfiguration(arguments: args, configFilePath: configFile ?? "/dev/null")
}

func makeTempConfigFile(contents: String) -> String {
    let path = "\(NSTemporaryDirectory())/scannerTests_\(UUID().uuidString).conf"
    try? contents.write(toFile: path, atomically: true, encoding: .utf8)
    return path
}

func makeTempOutputDir() -> String {
    let dir = "\(NSTemporaryDirectory())/scannerTests_\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    return dir
}

func createTempJPEGFile() -> URL {
    let path = "\(NSTemporaryDirectory())/scannerTests_\(UUID().uuidString).jpg"
    let size = NSSize(width: 10, height: 10)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.set()
    NSBezierPath.fill(NSRect(origin: .zero, size: size))
    image.unlockFocus()

    if
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let jpegData = bitmap.representation(using: .jpeg, properties: [:])
    {
        try? jpegData.write(to: URL(fileURLWithPath: path))
    }
    return URL(fileURLWithPath: path)
}

func createTempPNGFile() -> URL {
    let path = "\(NSTemporaryDirectory())/scannerTests_\(UUID().uuidString).png"
    let size = NSSize(width: 10, height: 10)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.red.set()
    NSBezierPath.fill(NSRect(origin: .zero, size: size))
    image.unlockFocus()

    if
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    {
        try? pngData.write(to: URL(fileURLWithPath: path))
    }
    return URL(fileURLWithPath: path)
}
