//
//  PDFAssembler.swift
//  scanner
//
//  Created by Dominic Rodemer on 09.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

// MARK: - PDFAssembler

/// Builds a multi-page PDF from scanned page images. Handles both Mixed Raster
/// Content (MRC) output and the plain single-image-per-page fallback via a single
/// hand-written PDF pipeline so that both branches honour `--resolution` and
/// `--jpeg-quality` identically.
///
/// In MRC mode each page is composed from two layers:
/// 1. A low-resolution JPEG color background (downsampled to `--resolution`).
/// 2. One or more high-resolution 1-bit text foregrounds. Text regions are
///    detected with Vision's `VNRecognizeTextRequest`, each region's dominant
///    ink color is sampled from the color source, and regions are clustered by
///    color. One `/ImageMask` XObject is emitted per color cluster, encoded
///    with CCITT Group 4 (via `NSBitmapImageRep`), and drawn with the cluster's
///    fill color. This preserves colored headlines (e.g. orange titles) instead
///    of rendering all text as black while still producing crisp edges
///    independent of the background's JPEG compression.
///
/// In no-MRC mode each page holds only the downsampled JPEG background — no
/// text detection, no mask. The background is compressed with `--jpeg-quality`
/// (higher default than the MRC background because text is being JPEG-encoded
/// directly and needs to stay legible).
///
/// CCITT Group 4 compression on the 1-bit text layer is roughly 2x smaller than
/// the Flate (zlib) compression that `CGPDFContext` uses by default, which is why
/// this type writes the PDF structure by hand instead of going through
/// `CGPDFContext`. The same hand-written pipeline is used for the no-MRC case so
/// that users get full control over the output JPEG quality (Apple's
/// `PDFDocument.write` silently picks its own aggressive defaults).
final class PDFAssembler: @unchecked Sendable {
    let configuration: ScanConfiguration

    init(configuration: ScanConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Assembles the given page URLs into a single multi-page PDF in the system
    /// temporary directory. Returns the output URL, or `nil` on failure.
    func assemble(urls: [URL]) -> URL? {
        guard !urls.isEmpty else { return nil }

        let pdf = PDFWriter()
        var pageRecords: [PageRecord] = []

        for (index, url) in urls.enumerated() {
            Logger.verbose("PDF: assembling page \(index + 1) / \(urls.count) from \(url.lastPathComponent)")
            guard let record = self.writePageContent(from: url, to: pdf) else {
                Logger.debug("PDF: failed to add page for \(url.lastPathComponent)")
                return nil
            }
            pageRecords.append(record)
        }

        // After every page's Bg/Mask/Contents XObjects are written, we write the Page
        // objects with forward references to the Pages parent (whose object number we
        // compute as nextObjectNumber + pages.count).
        let pagesRef = pdf.nextObjectNumber + pageRecords.count
        var pageObjectRefs: [Int] = []
        pageObjectRefs.reserveCapacity(pageRecords.count)

        for record in pageRecords {
            let pageRef = pdf.beginObject()
            pdf.writeLine("<<")
            pdf.writeLine("  /Type /Page")
            pdf.writeLine("  /Parent \(pagesRef) 0 R")
            pdf.writeLine(
                "  /MediaBox [0 0 \(Self.format(record.mediaBox.width)) \(Self.format(record.mediaBox.height))]"
            )
            var xObjects = "/Bg \(record.backgroundObjectRef) 0 R"
            for (i, mask) in record.maskRefs.enumerated() {
                xObjects += " /Mask\(i + 1) \(mask.objectRef) 0 R"
            }
            pdf.writeLine("  /Resources << /XObject << \(xObjects) >> >>")
            pdf.writeLine("  /Contents \(record.contentObjectRef) 0 R")
            pdf.writeLine(">>")
            pdf.endObject()
            pageObjectRefs.append(pageRef)
        }

        // Pages object referencing all Page objects.
        let pagesObjRef = pdf.beginObject()
        assert(pagesObjRef == pagesRef, "page-object forward reference mismatch")
        let kids = pageObjectRefs.map { "\($0) 0 R" }.joined(separator: " ")
        pdf.writeLine("<<")
        pdf.writeLine("  /Type /Pages")
        pdf.writeLine("  /Kids [\(kids)]")
        pdf.writeLine("  /Count \(pageObjectRefs.count)")
        pdf.writeLine(">>")
        pdf.endObject()

        // Catalog.
        let catalogRef = pdf.beginObject()
        pdf.writeLine("<< /Type /Catalog /Pages \(pagesObjRef) 0 R >>")
        pdf.endObject()

        let outputPath = "\(NSTemporaryDirectory())/scan.pdf"
        let outputURL = URL(fileURLWithPath: outputPath)
        let pdfData = pdf.finalize(rootRef: catalogRef)
        do {
            try pdfData.write(to: outputURL)
        } catch {
            Logger.error(error)
            return nil
        }
        return outputURL
    }

    // MARK: - Page composition

    /// Per-page record of the XObject and content stream references needed to emit
    /// the final `/Page` dictionary after all pages have been written.
    private struct PageRecord {
        let backgroundObjectRef: Int
        let maskRefs: [MaskRef]
        let contentObjectRef: Int
        let mediaBox: CGRect
    }

    /// Reference to a single per-color mask XObject together with the fill color it
    /// should be drawn with. One `MaskRef` is emitted per detected text-color cluster.
    private struct MaskRef {
        let objectRef: Int
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
    }

    /// Encoded mask bytes plus the cluster fill color, returned by the text-mask
    /// pipeline for each color group.
    private struct MaskEntry {
        let data: Data
        let width: Int
        let height: Int
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
    }

    private typealias Box = (x0: Int, y0: Int, x1: Int, y1: Int)

    /// Loads the scan, writes the background JPEG (and, in MRC mode, the text mask)
    /// and the page content stream as indirect objects in the PDF writer, then returns
    /// the collected references.
    private func writePageContent(from url: URL, to pdf: PDFWriter) -> PageRecord? {
        guard let source = self.loadImage(at: url) else {
            return nil
        }

        let isMRC = self.configuration.isMRCEnabled
        let backgroundDPI = self.configuredBackgroundResolution
        // Fallback DPI for the rare case where the scanned file has no DPI metadata:
        // in MRC mode the scanner is driven at --mrc-resolution, otherwise at --resolution.
        let fallbackDPI = isMRC ? self.configuredMRCResolution : backgroundDPI
        let nativeDPI = self.readDPI(of: url) ?? fallbackDPI
        let backgroundQuality = self.configuredBackgroundQuality

        // Media box is derived from the native scan's physical dimensions and is
        // independent of any downsample we do downstream — the PDF just needs to
        // know the page's physical size.
        let widthPoints = CGFloat(source.width) * 72.0 / nativeDPI
        let heightPoints = CGFloat(source.height) * 72.0 / nativeDPI
        let mediaBox = CGRect(x: 0, y: 0, width: widthPoints, height: heightPoints)

        // Background XObject: downsample native source to --resolution. This runs in
        // both MRC and no-MRC modes so that `--resolution` is the exact output DPI of
        // the embedded JPEG regardless of the scanner's native capture resolution.
        guard
            let background = self.backgroundJPEGBytes(
                source,
                targetDPI: backgroundDPI,
                sourceDPI: nativeDPI,
                quality: backgroundQuality
            ) else
        {
            Logger.debug("PDF: failed to encode background JPEG")
            return nil
        }

        let bgDict = """
        <<
          /Type /XObject
          /Subtype /Image
          /Width \(background.width)
          /Height \(background.height)
          /BitsPerComponent 8
          /ColorSpace /DeviceRGB
          /Filter /DCTDecode
          /Length \(background.data.count)
        >>
        """
        let bgRef = pdf.writeStreamObject(dict: bgDict, stream: background.data)

        // Text mask XObjects — MRC only. Downsample the color source to --mrc-resolution
        // before binarization when the scanner delivered a higher DPI than requested,
        // so the output masks are always at exactly the requested text-layer resolution.
        // Downsampling happens on the color (8-bit) image rather than on the finished
        // 1-bit masks, so text stroke edges stay clean.
        var maskRefs: [MaskRef] = []
        if isMRC {
            let textLayerDPI = self.configuredMRCResolution
            let maskColorSource: CGImage
            if
                nativeDPI > textLayerDPI,
                let downsampled = self.downsampleColorImage(source, fromDPI: nativeDPI, toDPI: textLayerDPI)
            {
                maskColorSource = downsampled
                Logger.verbose(
                    "MRC: scanner delivered \(Int(nativeDPI)) DPI; downsampling to \(Int(textLayerDPI)) DPI for text layer"
                )
            } else {
                maskColorSource = source
                Logger.verbose("MRC: using \(Int(nativeDPI)) DPI native scan for text layer")
            }

            let entries = self.textMaskEntries(for: maskColorSource)
            if entries.isEmpty {
                Logger.verbose("MRC: no text detected on this page; emitting background only")
            }
            for entry in entries {
                let maskDict = """
                <<
                  /Type /XObject
                  /Subtype /Image
                  /Width \(entry.width)
                  /Height \(entry.height)
                  /BitsPerComponent 1
                  /ImageMask true
                  /Filter /CCITTFaxDecode
                  /DecodeParms << /K -1 /Columns \(entry.width) /Rows \(entry.height) >>
                  /Length \(entry.data.count)
                >>
                """
                let ref = pdf.writeStreamObject(dict: maskDict, stream: entry.data)
                maskRefs.append(MaskRef(objectRef: ref, r: entry.r, g: entry.g, b: entry.b))
            }
        }

        // Content stream: draw the background across the media box, then draw each
        // per-color 1-bit mask with its cluster fill color. Image XObjects are drawn
        // in the unit square; the `cm` operator scales them to fill the page.
        var content = ""
        content += "q\n"
        content += "\(Self.format(widthPoints)) 0 0 \(Self.format(heightPoints)) 0 0 cm\n"
        content += "/Bg Do\n"
        content += "Q\n"
        for (i, mask) in maskRefs.enumerated() {
            content += "q\n"
            content += "\(Self.format(mask.r)) \(Self.format(mask.g)) \(Self.format(mask.b)) rg\n"
            content += "\(Self.format(widthPoints)) 0 0 \(Self.format(heightPoints)) 0 0 cm\n"
            content += "/Mask\(i + 1) Do\n"
            content += "Q\n"
        }
        let contentData = Data(content.utf8)
        let contentDict = """
        <<
          /Length \(contentData.count)
        >>
        """
        let contentRef = pdf.writeStreamObject(dict: contentDict, stream: contentData)

        return PageRecord(
            backgroundObjectRef: bgRef,
            maskRefs: maskRefs,
            contentObjectRef: contentRef,
            mediaBox: mediaBox
        )
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

    /// JPEG quality for the page background. In MRC mode we read `--mrc-jpeg-quality`
    /// (aggressive default of 20 — the 1-bit mask protects text so the background can
    /// be crunched). In no-MRC mode we read `--jpeg-quality` (default 60 — text is
    /// being JPEG-encoded directly so the quality floor has to stay higher). The raw
    /// integer percentage is clamped to 0–100 and mapped to Core Graphics's 0.0–1.0
    /// range; non-numeric values fall back to the option default.
    private var configuredBackgroundQuality: CGFloat {
        let option: ConfigOption
        let fallback: Int
        if self.configuration.isMRCEnabled {
            option = .mrcJpegQuality
            fallback = 20
        } else {
            option = .jpegQuality
            fallback = 60
        }
        let raw = self.configuration.string(option) ?? String(fallback)
        let parsed = Int(raw) ?? fallback
        let clamped = max(0, min(100, parsed))
        return CGFloat(clamped) / 100.0
    }

    // MARK: - Color downsample

    /// Downsamples a color CGImage from its source DPI to a target DPI using a high-quality
    /// bitmap context. Never upsamples: if `toDPI >= fromDPI` the source is returned unchanged.
    /// This is the shared resizing primitive used by both the background JPEG encoder and the
    /// text-mask pipeline, so that both paths get identical resampling behavior.
    private func downsampleColorImage(_ image: CGImage, fromDPI: CGFloat, toDPI: CGFloat) -> CGImage? {
        if toDPI >= fromDPI {
            return image
        }
        let scale = toDPI / fromDPI
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
        return ctx.makeImage()
    }

    // MARK: - Background JPEG

    /// Downsamples the color page to the target background DPI and JPEG-encodes it.
    /// Returns the raw JPEG bytes along with the encoded pixel dimensions, suitable for
    /// direct embedding as a PDF `/DCTDecode` stream.
    private func backgroundJPEGBytes(
        _ image: CGImage,
        targetDPI: CGFloat,
        sourceDPI: CGFloat,
        quality: CGFloat
    )
        -> (data: Data, width: Int, height: Int)?
    {
        guard let downsampled = self.downsampleColorImage(image, fromDPI: sourceDPI, toDPI: targetDPI) else {
            return nil
        }

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

        return (data: data as Data, width: downsampled.width, height: downsampled.height)
    }

    // MARK: - Text mask pipeline

    /// Builds one CCITT Group 4 compressed 1-bit text mask per detected ink-color
    /// cluster on the given color page. Returns an empty array if no text regions
    /// were detected (in which case the page falls back to background-only).
    ///
    /// Color clustering: the page is rendered to RGBA once, text regions are
    /// detected with Vision, each region's dominant ink color is sampled from its
    /// darkest ~20% of pixels, and regions are grouped greedily into clusters with
    /// a ΔRGB threshold. Each cluster produces a dedicated mask covering only the
    /// regions assigned to it, which the content stream then fills with the
    /// cluster's average color. Scanned black-text-only pages collapse to a single
    /// cluster matching the previous single-mask behavior.
    private func textMaskEntries(for color: CGImage) -> [MaskEntry] {
        let width = color.width
        let height = color.height
        let pixelCount = width * height

        guard let rgba = self.renderRGBA(color) else {
            return []
        }
        defer { rgba.deallocate() }

        // Derive grayscale from the RGBA buffer so color sampling and Sauvola
        // thresholding operate on bit-identical pixel data.
        let gray = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount)
        defer { gray.deallocate() }
        for i in 0..<pixelCount {
            let r = Int(rgba[i * 4])
            let g = Int(rgba[i * 4 + 1])
            let b = Int(rgba[i * 4 + 2])
            gray[i] = UInt8((r * 299 + g * 587 + b * 114) / 1000)
        }

        let boxes = self.detectTextBoxes(in: color)
        if boxes.isEmpty {
            return []
        }

        let clusters = self.clusterBoxesByInkColor(
            boxes: boxes,
            rgba: rgba,
            width: width,
            height: height
        )
        if clusters.isEmpty {
            return []
        }
        Logger.verbose("MRC: grouped text into \(clusters.count) color cluster(s)")

        guard
            let (integral, integralSq) = self.buildIntegralImages(
                gray,
                width: width,
                height: height
            ) else
        {
            return []
        }
        defer {
            integral.deallocate()
            integralSq.deallocate()
        }

        var entries: [MaskEntry] = []
        entries.reserveCapacity(clusters.count)
        for cluster in clusters {
            let inBoxMask = self.buildInBoxMask(boxes: cluster.boxes, width: width, height: height)
            defer { inBoxMask.deallocate() }

            let maskBuffer = self.runSauvola(
                gray: gray,
                inBox: inBoxMask,
                integral: integral,
                integralSq: integralSq,
                width: width,
                height: height
            )
            defer { maskBuffer.deallocate() }

            guard
                let encoded = self.ccittG4Encode(
                    inkBuffer: maskBuffer,
                    width: width,
                    height: height
                ) else
            {
                continue
            }

            entries.append(
                MaskEntry(
                    data: encoded.data,
                    width: encoded.width,
                    height: encoded.height,
                    r: cluster.r,
                    g: cluster.g,
                    b: cluster.b
                )
            )
        }
        return entries
    }

    // MARK: - RGBA rendering

    private func renderRGBA(_ image: CGImage) -> UnsafeMutablePointer<UInt8>? {
        let width = image.width
        let height = image.height
        let capacity = width * height * 4
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        buffer.initialize(repeating: 0, count: capacity)

        let space = CGColorSpaceCreateDeviceRGB()
        guard
            let ctx = CGContext(
                data: buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else
        {
            buffer.deallocate()
            return nil
        }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    // MARK: - Ink color sampling and clustering

    /// Mutable cluster state used during greedy color clustering.
    private struct ColorCluster {
        var boxes: [Box]
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
        var count: Int
    }

    /// Partitions text boxes into color clusters by sampling the dominant ink
    /// color of each box and merging boxes whose colors are within `distanceThreshold`
    /// (normalized RGB Euclidean distance). Capped at `maxClusters` to keep the
    /// number of mask XObjects bounded on noisy pages.
    private func clusterBoxesByInkColor(
        boxes: [Box],
        rgba: UnsafeMutablePointer<UInt8>,
        width: Int,
        height _: Int
    )
        -> [ColorCluster]
    {
        let distanceThreshold = 0.18
        let maxClusters = 8

        var clusters: [ColorCluster] = []
        for box in boxes {
            guard
                let color = self.dominantInkColor(
                    in: box,
                    rgba: rgba,
                    width: width
                ) else
            {
                continue
            }

            var bestIndex: Int?
            var bestDistance = Double.infinity
            for (i, cluster) in clusters.enumerated() {
                let dr = Double(cluster.r - color.r)
                let dg = Double(cluster.g - color.g)
                let db = Double(cluster.b - color.b)
                let d = (dr * dr + dg * dg + db * db).squareRoot()
                if d < bestDistance {
                    bestDistance = d
                    bestIndex = i
                }
            }

            if let idx = bestIndex, bestDistance < distanceThreshold {
                self.mergeColor(into: &clusters[idx], box: box, color: color)
            } else if clusters.count < maxClusters {
                clusters.append(
                    ColorCluster(
                        boxes: [box],
                        r: color.r,
                        g: color.g,
                        b: color.b,
                        count: 1
                    )
                )
            } else if let idx = bestIndex {
                // At capacity; fall back to the nearest cluster regardless of distance.
                self.mergeColor(into: &clusters[idx], box: box, color: color)
            }
        }
        return clusters
    }

    /// Running-mean merge of a box's sampled color into its target cluster.
    private func mergeColor(
        into cluster: inout ColorCluster,
        box: Box,
        color: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) {
        let n = CGFloat(cluster.count)
        cluster.r = (cluster.r * n + color.r) / (n + 1)
        cluster.g = (cluster.g * n + color.g) / (n + 1)
        cluster.b = (cluster.b * n + color.b) / (n + 1)
        cluster.count += 1
        cluster.boxes.append(box)
    }

    /// Estimates the dominant ink color inside a text box by averaging the RGB of
    /// pixels whose luminance falls within the darkest ~20% of the box. Uses a
    /// 256-bucket histogram to pick the cutoff in a single pass so that text on
    /// a light background yields near-ink color even when that ink isn't
    /// strictly "dark" (e.g. orange headlines).
    private func dominantInkColor(
        in box: Box,
        rgba: UnsafeMutablePointer<UInt8>,
        width: Int
    )
        -> (r: CGFloat, g: CGFloat, b: CGFloat)?
    {
        let boxWidth = box.x1 - box.x0
        let boxHeight = box.y1 - box.y0
        let totalPixels = boxWidth * boxHeight
        guard totalPixels > 0 else { return nil }

        var hist = [Int](repeating: 0, count: 256)
        for y in box.y0..<box.y1 {
            let row = rgba + (y * width + box.x0) * 4
            for i in 0..<boxWidth {
                let r = Int(row[i * 4])
                let g = Int(row[i * 4 + 1])
                let b = Int(row[i * 4 + 2])
                let lum = (r * 299 + g * 587 + b * 114) / 1000
                hist[lum] += 1
            }
        }

        let targetCount = max(1, totalPixels / 5)
        var cumulative = 0
        var cutoff = 0
        for lum in 0..<256 {
            cumulative += hist[lum]
            if cumulative >= targetCount {
                cutoff = lum
                break
            }
        }

        var rSum: UInt64 = 0
        var gSum: UInt64 = 0
        var bSum: UInt64 = 0
        var count: UInt64 = 0
        for y in box.y0..<box.y1 {
            let row = rgba + (y * width + box.x0) * 4
            for i in 0..<boxWidth {
                let r = row[i * 4]
                let g = row[i * 4 + 1]
                let b = row[i * 4 + 2]
                let lum = (Int(r) * 299 + Int(g) * 587 + Int(b) * 114) / 1000
                if lum <= cutoff {
                    rSum += UInt64(r)
                    gSum += UInt64(g)
                    bSum += UInt64(b)
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        return (
            r: CGFloat(Double(rSum) / Double(count) / 255.0),
            g: CGFloat(Double(gSum) / Double(count) / 255.0),
            b: CGFloat(Double(bSum) / Double(count) / 255.0)
        )
    }

    // MARK: - Vision text detection

    /// Runs `VNRecognizeTextRequest` on the page and returns expanded pixel-space boxes
    /// (top-left origin). The boxes are padded slightly to avoid clipping stroke edges
    /// during binarization.
    private func detectTextBoxes(in image: CGImage) -> [Box] {
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

        var boxes: [Box] = []
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
        boxes: [Box],
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

    // MARK: - CCITT Group 4 encoding

    /// Packs the 8-bit ink buffer into a 1-bit stream and runs it through
    /// `NSBitmapImageRep` with `.ccittfax4` TIFF compression. The encoded strip
    /// bytes from the TIFF are binary-compatible with PDF's `/CCITTFaxDecode`
    /// filter when `K=-1` (Group 4) and default `BlackIs1` (false).
    ///
    /// The packing convention is bit = 1 at ink pixels, which `NSBitmapImageRep`
    /// with `.calibratedWhite` color space interprets as "white" and emits with
    /// `photometric = 1` (BlackIsZero) in the TIFF. The PDF CCITT decoder reads
    /// the same bits and, with default `BlackIs1 false`, treats bit = 1 as sample
    /// value 1 (white) → transparent, and bit = 0 as sample value 0 (black) →
    /// painted. Combined with the default image-mask `/Decode [0 1]`, ink pixels
    /// paint through with the current fill color (which we set to black).
    private func ccittG4Encode(
        inkBuffer: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int
    )
        -> (data: Data, width: Int, height: Int)?
    {
        let bytesPerRow = (width + 7) / 8
        let packedSize = bytesPerRow * height

        let packed = UnsafeMutablePointer<UInt8>.allocate(capacity: packedSize)
        defer { packed.deallocate() }
        packed.initialize(repeating: 0, count: packedSize)

        for y in 0..<height {
            let src = inkBuffer + y * width
            let dst = packed + y * bytesPerRow
            for x in 0..<width where src[x] == 0 {
                let byteIdx = x >> 3
                let bitIdx = 7 - (x & 7)
                dst[byteIdx] |= UInt8(1 << bitIdx)
            }
        }

        // NSBitmapImageRep(bitmapDataPlanes:) references but does not copy the buffer.
        // `packed` stays alive for the duration of this function via the `defer`, so
        // `rep` and the TIFF generation call both see valid data.
        var planes: [UnsafeMutablePointer<UInt8>?] = [packed]
        let rep: NSBitmapImageRep? = planes.withUnsafeMutableBufferPointer { buf in
            NSBitmapImageRep(
                bitmapDataPlanes: buf.baseAddress,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 1,
                samplesPerPixel: 1,
                hasAlpha: false,
                isPlanar: false,
                colorSpaceName: .calibratedWhite,
                bytesPerRow: bytesPerRow,
                bitsPerPixel: 1
            )
        }
        guard let rep else {
            Logger.debug("MRC: failed to create NSBitmapImageRep for mask")
            return nil
        }

        guard
            let tiff = rep.representation(
                using: .tiff,
                properties: [.compressionMethod: NSBitmapImageRep.TIFFCompression.ccittfax4.rawValue]
            ) else
        {
            Logger.debug("MRC: failed to produce CCITT G4 TIFF")
            return nil
        }

        guard let stripBytes = Self.extractTIFFStripData(tiff) else {
            Logger.debug("MRC: failed to extract CCITT strip data from TIFF")
            return nil
        }

        return (data: stripBytes, width: width, height: height)
    }

    /// Parses the header and first IFD of a TIFF file and returns the concatenated
    /// compressed strip data. Assumes a single-image TIFF; multi-image TIFFs are
    /// not supported (and `NSBitmapImageRep` does not produce them here).
    private static func extractTIFFStripData(_ tiff: Data) -> Data? {
        guard tiff.count >= 8 else { return nil }
        let byteOrder = String(bytes: tiff[0..<2], encoding: .ascii) ?? ""
        let littleEndian: Bool
        switch byteOrder {
        case "II": littleEndian = true
        case "MM": littleEndian = false
        default: return nil
        }

        func u16(_ offset: Int) -> UInt16 {
            let a = UInt16(tiff[offset])
            let b = UInt16(tiff[offset + 1])
            return littleEndian ? (a | (b << 8)) : ((a << 8) | b)
        }
        func u32(_ offset: Int) -> UInt32 {
            let a = UInt32(tiff[offset])
            let b = UInt32(tiff[offset + 1])
            let c = UInt32(tiff[offset + 2])
            let d = UInt32(tiff[offset + 3])
            return littleEndian
                ? (a | (b << 8) | (c << 16) | (d << 24))
                : ((a << 24) | (b << 16) | (c << 8) | d)
        }

        guard u16(2) == 42 else { return nil }
        let ifdOffset = Int(u32(4))
        guard ifdOffset + 2 <= tiff.count else { return nil }
        let entryCount = Int(u16(ifdOffset))

        var stripOffsets: [Int] = []
        var stripByteCounts: [Int] = []

        for i in 0..<entryCount {
            let base = ifdOffset + 2 + i * 12
            guard base + 12 <= tiff.count else { return nil }
            let tag = u16(base)
            let type = u16(base + 2)
            let count = Int(u32(base + 4))
            let valueOffset = Int(u32(base + 8))

            let elementSize = type == 3 ? 2 : 4 // 3 = SHORT, 4 = LONG
            let totalBytes = elementSize * count
            let inline = totalBytes <= 4

            func readValues() -> [Int] {
                var out: [Int] = []
                out.reserveCapacity(count)
                for j in 0..<count {
                    let off = inline ? base + 8 + j * elementSize : valueOffset + j * elementSize
                    guard off + elementSize <= tiff.count else { continue }
                    if type == 3 {
                        out.append(Int(u16(off)))
                    } else if type == 4 {
                        out.append(Int(u32(off)))
                    }
                }
                return out
            }

            switch tag {
            case 273: stripOffsets = readValues() // StripOffsets
            case 279: stripByteCounts = readValues() // StripByteCounts
            default: break
            }
        }

        guard
            !stripOffsets.isEmpty,
            stripOffsets.count == stripByteCounts.count else
        {
            return nil
        }

        var combined = Data()
        for (off, len) in zip(stripOffsets, stripByteCounts) {
            guard off + len <= tiff.count else { return nil }
            combined.append(tiff.subdata(in: off..<(off + len)))
        }
        return combined
    }

    // MARK: - Formatting helpers

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.4f", Double(value))
    }
}

// MARK: - PDFWriter

/// Minimal hand-rolled PDF writer. Accumulates objects into a single buffer and
/// emits an xref table and trailer at finalize time.
///
/// This writer only supports what `PDFAssembler` needs: indirect objects with
/// arbitrary dictionaries, indirect stream objects with arbitrary payloads, and a
/// single trailer referencing a catalog object. Forward references are supported
/// by having callers compute the target object number up front (see the `Pages`
/// object in `PDFAssembler.assemble(urls:)`).
private final class PDFWriter {
    private var buffer = Data()
    private var offsets: [Int] = [0]

    init() {
        // Header + binary marker so byte-safe transport is preserved.
        self.writeLine("%PDF-1.5")
        self.buffer.append(contentsOf: [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A])
    }

    var nextObjectNumber: Int {
        self.offsets.count
    }

    func writeLine(_ line: String) {
        self.buffer.append(contentsOf: line.utf8)
        self.buffer.append(0x0A) // LF
    }

    func writeRaw(_ data: Data) {
        self.buffer.append(data)
    }

    @discardableResult
    func beginObject() -> Int {
        self.offsets.append(self.buffer.count)
        let num = self.offsets.count - 1
        self.writeLine("\(num) 0 obj")
        return num
    }

    func endObject() {
        self.writeLine("endobj")
    }

    /// Writes an indirect object that wraps a stream payload. The PDF spec requires
    /// an EOL between the closing `>>` of the dict and the `stream` keyword, and an
    /// EOL before `endstream`. The `/Length` of the dict must match the byte count
    /// of the raw stream payload exclusive of those EOLs.
    @discardableResult
    func writeStreamObject(dict: String, stream: Data) -> Int {
        let num = self.beginObject()
        self.writeLine(dict)
        self.writeLine("stream")
        self.writeRaw(stream)
        self.writeLine("")
        self.writeLine("endstream")
        self.endObject()
        return num
    }

    func finalize(rootRef: Int) -> Data {
        let xrefOffset = self.buffer.count
        self.writeLine("xref")
        self.writeLine("0 \(self.offsets.count)")
        self.writeLine("0000000000 65535 f ")
        for i in 1..<self.offsets.count {
            self.writeLine(String(format: "%010d 00000 n ", self.offsets[i]))
        }
        self.writeLine("trailer")
        self.writeLine("<< /Size \(self.offsets.count) /Root \(rootRef) 0 R >>")
        self.writeLine("startxref")
        self.writeLine("\(xrefOffset)")
        self.writeLine("%%EOF")
        return self.buffer
    }
}
