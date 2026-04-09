# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Mixed Raster Content (MRC) PDF output: text is detected with Vision's `VNRecognizeTextRequest`, binarized inside the text regions with Sauvola adaptive thresholding, and composed as a 1-bit image mask on top of a downsampled JPEG color background. Produces crisp text independent of the background JPEG's compression while preserving photos, logos, and color content in the background layer. **This is now the default for PDF output** — pass `--no-mrc` to opt out.
- `--no-mrc` flag to disable MRC output and fall back to the plain image-per-page PDF path. Ignored for non-PDF formats (`jpeg`, `tiff`, `png`).
- `--mrc-resolution <dpi>` option to set the text-layer resolution (default: 400). The scanner is driven at `max(--mrc-resolution, --resolution)` so the mask is built from a native high-resolution scan; the background is downsampled to `--resolution`.
- `--jpeg-quality <0-100>` option to control the MRC background JPEG quality (default: 50, higher = better quality, larger file). Non-numeric or out-of-range values fall back to the default. Only affects MRC PDF output — has no effect on `--format jpeg` or on rotated output.
- `MRCAssembler` class in `libscanner` implementing the full MRC pipeline (grayscale render, Vision text detection, integral-image Sauvola binarization, CCITT Group 4 mask encoding via `NSBitmapImageRep`, hand-written PDF composition).
- `ScanConfiguration.isMRCEnabled` computed property centralizes the "format == pdf && !--no-mrc" check.

### Changed
- **MRC is now the default for PDF output.** Previously gated behind an opt-in `--mrc` flag, MRC is now turned on whenever `--format pdf` is selected (which itself is the default). Users who want the old image-per-page PDF behavior can pass `--no-mrc`.
- MRC PDF assembly uses a hand-written PDF writer instead of `CGPDFContext`, and compresses the 1-bit text mask with CCITT Group 4 (`/CCITTFaxDecode`) instead of Flate. Background JPEGs are embedded directly as `/DCTDecode` streams. For a representative two-page German bank statement this reduces the MRC PDF size by ~44 % compared to a Flate-compressed 600 DPI mask implementation (923 KB → 516 KB), at visually indistinguishable quality.
- `--mrc-resolution` is an exact target, not a minimum. When the scanner delivers a higher native DPI than requested (e.g. asking for 400 DPI on a scanner that only supports 600), the color source is downsampled to the requested resolution before binarization, so the output mask is always at exactly `--mrc-resolution`. This matches user intent ("I asked for 400, I get 400") and gives consistent output across scanners with different supported-resolution sets.
- Print output file path after successful scan (e.g. `Saved to /path/to/scan.pdf`)
- `--version` flag to print version and exit
- Homebrew publish flow: GitHub Actions workflow builds bottles (arm64 + x86_64), creates GitHub releases, and auto-updates `domzilla/homebrew-tap` formula
- `.publish` config for unified publish script integration
- Rewrote README with installation, usage, options reference, config file docs, and build instructions

### Removed
- `-v` short flag for `--verbose` (use `--verbose` instead)

### Fixed
- Suppressed CoreGraphics PDF framework noise (`CoreGraphics PDF has logged an error`) from stderr during PDF creation

### Changed
- Refactored help output to data-driven architecture with `HelpFormatter` and DTOs (`HelpCommandDTO`, `CommandInfoDTO`, `ParameterInfoDTO`, `OptionGroupDTO`, `ExampleDTO`, `OutputInfoDTO`), matching the `events` CLI formatting style
- Help output now uses dynamic column alignment per section instead of fixed-width padding
- Options with values now show type hints (e.g. `--input <source>`, `--resolution <dpi>`)
- Help output written via `FileHandle.standardOutput` with `printAndExit` instead of `print()` + `exit()`

### Changed
- Moved `CLI.swift` from `libscanner` to `scanner` target — CLI parsing is now an executable concern, not a library concern
- Introduced `AppOptions` abstraction in `libscanner` with `Mode` enum (`.scan`/`.list`) and `timeout`, replacing global `CLI.listMode`/`CLI.timeout` statics
- `AppController` and `ScannerBrowser` now accept `AppOptions` instead of accessing CLI state directly
- `ScanConfiguration.init` now throws on parse errors instead of calling `CLI.exitWithError()`

### Changed
- Adopted standard POSIX/GNU flag convention: `--flag` for long options, `-x` for short options
- Added single-letter short flags for most options (e.g. `-d` for `--duplex`, `-f` for `--format`)
- Config file format updated to use `--flag` syntax (breaking change for existing config files)

### Fixed
- Fixed empty PDF being created when no pages were scanned
- Fixed `-h` flag not being recognized as help
- Invalid arguments now cause immediate exit with error instead of being silently ignored

### Changed
- Renamed config file from `~/.scanline.conf` to `~/.config/scanner/scanner.conf`
- Replaced all remaining "scanline" references in user-facing strings, README, and AGENTS.md
- Rewrote `-help` output with logical grouping, defaults, and usage examples
- Replaced mutually exclusive flags with enum options: `-input [feeder|flatbed]`, `-format [pdf|jpeg|tiff|png]`, `-size [a4|letter|legal]`, `-color [color|mono]`
- Removed all option synonyms (e.g. `-dup`, `-fb`, `-jpg`, `-bw`, `-v`, `-s`, `-res`, `-t`)
- Default page size changed from US Letter to A4
- `-list` is now a `list` subcommand (e.g. `scanner list`)
- `-browsesecs` renamed to `-timeout`, moved from scan config to CLI
- Extracted CLI argument parsing, help output, and subcommand handling into `CLI.swift`
- `-scanner` matching changed from prefix to case-insensitive substring
- Check document feeder has paper loaded before scanning; fail with actionable message if empty
- "Done" only printed on successful exit; removed redundant "Failed to scan document." message

### Added
- Complete Swift 6 rewrite under `src/scanner/` with filesystem-synced Xcode project
- `ScanConfiguration` — Pure Swift config with type-safe `ConfigOption` enum replacing Objective-C `ScanConfiguration.h/m`
- `ScannerBrowser` — Scanner discovery via ImageCaptureCore with fuzzy/exact name matching
- `ScannerController` — Scanner session management, functional unit configuration, batch mode
- `OutputProcessor` — Post-processing pipeline: rotation (CoreImage), PDF combining (PDFKit), file output
- `AppController` — Main orchestrator with CFRunLoop lifecycle

### Removed
- Apple Intelligence features: `-summarize`, `-summary`, `-autoname` flags and all FoundationModels/LLM integration
- OCR feature: `-ocr` flag and Vision framework dependency
- `-open` flag and file-open-after-scan feature

### Fixed
- Fixed build error: `IndexSet.integerGreaterThanOrEqual(to:)` does not exist in current SDK — replaced with `contains()` + `integerGreaterThan()` combination
- Restored runtime verbose logging (`-verbose` flag) — was replaced with `Logger.debug()` which is a no-op in release builds, making `-verbose` silently ignored

### Changed
- Migrated from Objective-C/Swift 5 hybrid to pure Swift 6
- Replaced `NSMutableDictionary`-based config with type-safe `[ConfigOption: ConfigValue]` dictionary
- Replaced `NSMutableArray` tags with `[String]`
- Made `ScanConfiguration` immutable (`Sendable`-conformant)
- `Logger` enum now provides three levels: `verbose()` (runtime, respects `-verbose` flag), `debug()` (DEBUG builds only), `error()` (DEBUG builds only)
- User-facing log messages use inline `log()` helpers
