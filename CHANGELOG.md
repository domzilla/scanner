# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Print output file path after successful scan (e.g. `Saved to /path/to/scan.pdf`)

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
