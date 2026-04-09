//
//  MRCAssembler.swift
//  scanner
//
//  Created by Dominic Rodemer on 09.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

// MARK: - MRCAssembler

/// Builds a Mixed Raster Content (MRC) PDF from scanned page images.
///
/// For each page the assembler produces two layers composed on a CGPDFContext page:
/// 1. A low-resolution JPEG color background (the full page at the configured `--resolution`).
/// 2. A high-resolution 1-bit text foreground. Text regions are detected with Vision's
///    `VNRecognizeTextRequest` and binarized inside those regions with Sauvola adaptive
///    thresholding. The resulting mask is embedded as a `/ImageMask` XObject and drawn
///    with a black fill color, producing crisp text independent of the background's
///    JPEG compression.
///
/// This preserves photos, logos, and other non-text content in the JPEG background layer
/// untouched, while keeping text sharp at the native scan resolution.
final class MRCAssembler: @unchecked Sendable {
    let configuration: ScanConfiguration

    init(configuration: ScanConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Assembles the given page URLs into a single multi-page MRC PDF in the system
    /// temporary directory. Returns the output URL, or `nil` on failure.
    func assemble(urls: [URL]) -> URL? {
        guard !urls.isEmpty else { return nil }

        let outputPath = "\(NSTemporaryDirectory())/scan.pdf"
        let outputURL = URL(fileURLWithPath: outputPath)

        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            Logger.debug("Failed to create CGDataConsumer for \(outputPath)")
            return nil
        }

        // Placeholder media box — each page overrides this via beginPDFPage pageInfo.
        var placeholder = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &placeholder, nil) else {
            Logger.debug("Failed to create CGPDFContext")
            return nil
        }

        for (index, url) in urls.enumerated() {
            Logger.verbose("MRC: assembling page \(index + 1) / \(urls.count) from \(url.lastPathComponent)")
            if !self.addPage(from: url, to: pdfContext) {
                Logger.debug("MRC: failed to add page for \(url.lastPathComponent)")
                pdfContext.closePDF()
                return nil
            }
        }

        pdfContext.closePDF()
        return outputURL
    }

    // MARK: - Page composition

    private func addPage(from url: URL, to pdfContext: CGContext) -> Bool {
        guard let color = self.loadImage(at: url) else {
            return false
        }

        let sourceDPI = self.readDPI(of: url) ?? self.configuredMRCResolution
        let backgroundDPI = self.configuredBackgroundResolution
        let backgroundQuality = self.configuredBackgroundQuality

        let widthPoints = CGFloat(color.width) * 72.0 / sourceDPI
        let heightPoints = CGFloat(color.height) * 72.0 / sourceDPI
        var mediaBox = CGRect(x: 0, y: 0, width: widthPoints, height: heightPoints)

        let pageInfo: [CFString: Any] = [
            kCGPDFContextMediaBox: CFDataCreate(
                nil,
                withUnsafeBytes(of: &mediaBox) { Array($0) },
                MemoryLayout<CGRect>.size
            )!,
        ]
        pdfContext.beginPDFPage(pageInfo as CFDictionary)
        defer { pdfContext.endPDFPage() }

        // Background layer: downsampled JPEG across the entire media box.
        if
            let background = self.downsampledJPEG(
                color,
                targetDPI: backgroundDPI,
                sourceDPI: sourceDPI,
                quality: backgroundQuality
            )
        {
            pdfContext.draw(background, in: mediaBox)
        } else {
            // If the downsample fails, fall back to drawing the full-resolution source so the
            // page is never blank. This also keeps the document legible on a failed MRC path.
            Logger.debug("MRC: background downsample failed; drawing source image instead")
            pdfContext.draw(color, in: mediaBox)
        }

        // Foreground layer: Sauvola-binarized text mask drawn with black fill.
        if let textMask = self.buildTextMask(for: color) {
            pdfContext.saveGState()
            pdfContext.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
            pdfContext.draw(textMask, in: mediaBox)
            pdfContext.restoreGState()
        } else {
            Logger.verbose("MRC: no text detected on this page; emitting background only")
        }

        return true
    }

    // MARK: - Image loading

    private func loadImage(at url: URL) -> CGImage? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else
        {
            return nil
        }
        return image
    }

    /// Reads the source DPI from the JPEG's ImageIO properties. Returns `nil` if
    /// the metadata is missing or unreadable — caller can fall back to a configured value.
    private func readDPI(of url: URL) -> CGFloat? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else
        {
            return nil
        }
        if let value = properties[kCGImagePropertyDPIWidth] as? CGFloat {
            return value
        }
        if let number = properties[kCGImagePropertyDPIWidth] as? NSNumber {
            return CGFloat(number.doubleValue)
        }
        return nil
    }

    // MARK: - Configured values

    private var configuredMRCResolution: CGFloat {
        let raw = self.configuration.string(.mrcResolution) ?? "400"
        return CGFloat(Int(raw) ?? 400)
    }

    private var configuredBackgroundResolution: CGFloat {
        let raw = self.configuration.string(.resolution) ?? "150"
        return CGFloat(Int(raw) ?? 150)
    }

    /// JPEG quality for the background layer. Fixed default; exposed as a constant so
    /// it's easy to make configurable later if needed.
    private var configuredBackgroundQuality: CGFloat {
        0.5
    }

    // MARK: - Background downsample

    private func downsampledJPEG(
        _ image: CGImage,
        targetDPI: CGFloat,
        sourceDPI: CGFloat,
        quality: CGFloat
    )
        -> CGImage?
    {
        // Never upsample: if the background DPI is higher than the source, just re-encode
        // at the source resolution.
        let scale = min(1.0, targetDPI / sourceDPI)
        let newWidth = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let newHeight = max(1, Int((CGFloat(image.height) * scale).rounded()))

        let space = CGColorSpaceCreateDeviceRGB()
        guard
            let ctx = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else
        {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        guard let downsampled = ctx.makeImage() else { return nil }

        // Re-encode as JPEG. We re-decode the result so CGPDFContext embeds the JPEG
        // bytes as a DCTDecode stream, rather than re-encoding a raw bitmap.
        let data = NSMutableData()
        guard
            let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else
        {
            return nil
        }
        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
        ]
        CGImageDestinationAddImage(dest, downsampled, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            return nil
        }

        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let jpegImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else
        {
            return nil
        }
        return jpegImage
    }

    // MARK: - Text mask pipeline

    /// Builds a 1-bit CGImage text mask for the given color page, or `nil` if no text
    /// regions were detected (in which case the page falls back to background-only).
    private func buildTextMask(for color: CGImage) -> CGImage? {
        let width = color.width
        let height = color.height

        guard let grayBuffer = self.renderGrayscale(color) else {
            return nil
        }
        defer { grayBuffer.deallocate() }

        let boxes = self.detectTextBoxes(in: color)
        if boxes.isEmpty {
            return nil
        }

        let inBoxMask = self.buildInBoxMask(boxes: boxes, width: width, height: height)
        defer { inBoxMask.deallocate() }

        guard
            let (integral, integralSq) = self.buildIntegralImages(
                grayBuffer,
                width: width,
                height: height
            ) else
        {
            return nil
        }
        defer {
            integral.deallocate()
            integralSq.deallocate()
        }

        let maskBuffer = self.runSauvola(
            gray: grayBuffer,
            inBox: inBoxMask,
            integral: integral,
            integralSq: integralSq,
            width: width,
            height: height
        )
        defer { maskBuffer.deallocate() }

        return self.buildImageMask(from: maskBuffer, width: width, height: height)
    }

    // MARK: - Grayscale rendering

    private func renderGrayscale(_ image: CGImage) -> UnsafeMutablePointer<UInt8>? {
        let width = image.width
        let height = image.height
        let capacity = width * height
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        buffer.initialize(repeating: 0, count: capacity)

        let space = CGColorSpaceCreateDeviceGray()
        guard
            let ctx = CGContext(
                data: buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: space,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else
        {
            buffer.deallocate()
            return nil
        }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    // MARK: - Vision text detection

    /// Runs `VNRecognizeTextRequest` on the page and returns expanded pixel-space boxes
    /// (top-left origin). The boxes are padded slightly to avoid clipping stroke edges
    /// during binarization.
    private func detectTextBoxes(in image: CGImage) -> [(x0: Int, y0: Int, x1: Int, y1: Int)] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = true

        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            Logger.error(error)
            return []
        }

        let observations = (request.results ?? []) as [VNRecognizedTextObservation]
        let width = image.width
        let height = image.height
        let padding = 12

        var boxes: [(x0: Int, y0: Int, x1: Int, y1: Int)] = []
        boxes.reserveCapacity(observations.count)
        for obs in observations {
            let b = obs.boundingBox
            let px0 = Int((b.minX * CGFloat(width)).rounded(.down)) - padding
            let py0Bottom = Int((b.minY * CGFloat(height)).rounded(.down)) - padding
            let px1 = Int((b.maxX * CGFloat(width)).rounded(.up)) + padding
            let py1Bottom = Int((b.maxY * CGFloat(height)).rounded(.up)) + padding
            // Vision box origin is bottom-left; our bitmap is top-left. Flip Y.
            let y0 = max(0, height - py1Bottom)
            let y1 = min(height, height - py0Bottom)
            let x0 = max(0, px0)
            let x1 = min(width, px1)
            if x1 > x0, y1 > y0 {
                boxes.append((x0, y0, x1, y1))
            }
        }
        Logger.verbose("MRC: detected \(boxes.count) text regions")
        return boxes
    }

    // MARK: - In-box mask

    private func buildInBoxMask(
        boxes: [(x0: Int, y0: Int, x1: Int, y1: Int)],
        width: Int,
        height: Int
    )
        -> UnsafeMutablePointer<UInt8>
    {
        let capacity = width * height
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        buffer.initialize(repeating: 0, count: capacity)
        for box in boxes {
            for y in box.y0..<box.y1 {
                let row = buffer + y * width
                for x in box.x0..<box.x1 {
                    row[x] = 1
                }
            }
        }
        return buffer
    }

    // MARK: - Integral images

    /// Builds (width+1) x (height+1) integral and integral-of-squares tables over the
    /// grayscale buffer. Both tables use UInt64 to accommodate 8-bit sums over tens of
    /// millions of pixels without overflow.
    private func buildIntegralImages(
        _ gray: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int
    )
        -> (UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>)?
    {
        let iw = width + 1
        let ih = height + 1
        let count = iw * ih
        let integral = UnsafeMutablePointer<UInt64>.allocate(capacity: count)
        let integralSq = UnsafeMutablePointer<UInt64>.allocate(capacity: count)
        integral.initialize(repeating: 0, count: count)
        integralSq.initialize(repeating: 0, count: count)

        for y in 0..<height {
            var rowSum: UInt64 = 0
            var rowSumSq: UInt64 = 0
            let srcRow = gray + y * width
            let prevIntRow = integral + y * iw
            let currIntRow = integral + (y + 1) * iw
            let prevSqRow = integralSq + y * iw
            let currSqRow = integralSq + (y + 1) * iw
            for x in 0..<width {
                let v = UInt64(srcRow[x])
                rowSum += v
                rowSumSq += v * v
                currIntRow[x + 1] = prevIntRow[x + 1] + rowSum
                currSqRow[x + 1] = prevSqRow[x + 1] + rowSumSq
            }
        }
        return (integral, integralSq)
    }

    // MARK: - Sauvola thresholding

    /// Runs Sauvola adaptive thresholding inside the in-box regions only.
    /// Pixels outside the text boxes are left as background (255). Inside the boxes,
    /// each pixel is compared against a local threshold computed from the integral images.
    ///
    ///     T(x, y) = mean(x, y) * (1 + k * (std(x, y) / R - 1))
    ///
    /// Output is an 8-bit grayscale buffer where 0 = ink, 255 = background.
    private func runSauvola(
        gray: UnsafeMutablePointer<UInt8>,
        inBox: UnsafeMutablePointer<UInt8>,
        integral: UnsafeMutablePointer<UInt64>,
        integralSq: UnsafeMutablePointer<UInt64>,
        width: Int,
        height: Int
    )
        -> UnsafeMutablePointer<UInt8>
    {
        let output = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
        output.initialize(repeating: 255, count: width * height)

        let radius = 20
        let k = 0.2
        let R = 128.0
        let minStdFloor = 1.0
        let iw = width + 1

        for y in 0..<height {
            let inRow = inBox + y * width
            let srcRow = gray + y * width
            let outRow = output + y * width

            let y0 = max(0, y - radius)
            let y1 = min(height, y + radius + 1)
            let iy0 = y0 * iw
            let iy1 = y1 * iw

            for x in 0..<width {
                if inRow[x] == 0 { continue }

                let x0 = max(0, x - radius)
                let x1 = min(width, x + radius + 1)
                let area = UInt64((x1 - x0) * (y1 - y0))

                // Integral-image subtraction can underflow in intermediate UInt64 steps
                // while still producing a non-negative final value. Use wrapping ops so
                // the compiler does not insert overflow traps.
                let sum = integral[iy1 + x1]
                    &- integral[iy1 + x0]
                    &- integral[iy0 + x1]
                    &+ integral[iy0 + x0]
                let sumSq = integralSq[iy1 + x1]
                    &- integralSq[iy1 + x0]
                    &- integralSq[iy0 + x1]
                    &+ integralSq[iy0 + x0]

                let mean = Double(sum) / Double(area)
                let variance = max(0, Double(sumSq) / Double(area) - mean * mean)
                let std = max(minStdFloor, sqrt(variance))

                let threshold = mean * (1.0 + k * (std / R - 1.0))
                if Double(srcRow[x]) < threshold {
                    outRow[x] = 0
                }
            }
        }
        return output
    }

    // MARK: - 1-bit image mask

    /// Packs the 8-bit grayscale ink buffer into a 1-bit CGImage image mask suitable for
    /// `CGContext.draw(_:in:)` with a fill color. Bit = 1 means "ink", which we then map
    /// via `decode: [1, 0]` to opaque paint-through. Apple's docs say `decode: nil` should
    /// default to `[1, 0]` for image masks, but on current macOS the nil default behaves
    /// like `[0, 1]` (no inversion), so we set it explicitly.
    private func buildImageMask(
        from buffer: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int
    )
        -> CGImage?
    {
        let packedBytesPerRow = (width + 7) / 8
        let packedSize = packedBytesPerRow * height

        let packed = UnsafeMutablePointer<UInt8>.allocate(capacity: packedSize)
        packed.initialize(repeating: 0, count: packedSize)
        defer { packed.deallocate() }

        for y in 0..<height {
            let src = buffer + y * width
            let dst = packed + y * packedBytesPerRow
            for x in 0..<width where src[x] == 0 {
                let byteIdx = x >> 3
                let bitIdx = 7 - (x & 7)
                dst[byteIdx] |= UInt8(1 << bitIdx)
            }
        }

        let data = Data(bytes: packed, count: packedSize)
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        let decode: [CGFloat] = [1, 0]
        return decode.withUnsafeBufferPointer { buf in
            CGImage(
                maskWidth: width,
                height: height,
                bitsPerComponent: 1,
                bitsPerPixel: 1,
                bytesPerRow: packedBytesPerRow,
                provider: provider,
                decode: buf.baseAddress,
                shouldInterpolate: false
            )
        }
    }
}
