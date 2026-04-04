# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Complete Swift 6 rewrite under `src/scanner/` with filesystem-synced Xcode project
- `ScanConfiguration` — Pure Swift config with type-safe `ConfigOption` enum replacing Objective-C `ScanConfiguration.h/m`
- `ScannerBrowser` — Scanner discovery via ImageCaptureCore with fuzzy/exact name matching
- `ScannerController` — Scanner session management, functional unit configuration, batch mode
- `OutputProcessor` — Post-processing pipeline: OCR (Vision), rotation (CoreImage), PDF combining (PDFKit), file output with tag-based aliasing
- `AppController` — Main orchestrator with CFRunLoop lifecycle

### Removed
- Apple Intelligence features: `-summarize`, `-summary`, `-autoname` flags and all FoundationModels/LLM integration

### Fixed
- Fixed build error: `IndexSet.integerGreaterThanOrEqual(to:)` does not exist in current SDK — replaced with `contains()` + `integerGreaterThan()` combination
- Restored runtime verbose logging (`-verbose` flag) — was replaced with `Logger.debug()` which is a no-op in release builds, making `-verbose` silently ignored

### Changed
- Migrated from Objective-C/Swift 5 hybrid to pure Swift 6
- Replaced `NSMutableDictionary`-based config with type-safe `[ConfigOption: ConfigValue]` dictionary
- Replaced `NSMutableArray` tags with `[String]`
- Made `ScanConfiguration` immutable (`Sendable`-conformant)
- `Logger` enum now provides three levels: `verbose()` (runtime, respects `-verbose` flag), `debug()` (DEBUG builds only), `error()` (DEBUG builds only)
- User-facing log messages use inline `log()` helpers that route to stderr in OCR mode
