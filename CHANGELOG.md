# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
