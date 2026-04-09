# test-images/

Drop image files here (jpg/jpeg/png/tif/tiff) to use as input for the `--debug-input` flag when iterating on the output pipeline without a physical scanner.

Everything in this directory is gitignored except this README — images stay local to your machine so the repo doesn't accumulate sample scans.

## Layout

Group fixtures by scenario in subdirectories so you can drive the pipeline against a specific test case without reshuffling files. One subdirectory per resolution / scanner / document type:

```
test-images/
├── 600dpi/      # scan1.jpg, scan2.jpg (bank statement, 600 DPI native)
├── 300dpi/      # (your 300 DPI fixtures)
└── mono/        # (1-bit mono fixtures)
```

Create more subdirectories as needed. Every subdirectory is gitignored.

## Usage

```bash
# Single image
/tmp/scanner-build/Debug/scanner --debug-input test-images/600dpi/scan1.jpg --name repro

# Whole subdirectory (sorted lexicographically by filename)
/tmp/scanner-build/Debug/scanner --debug-input test-images/600dpi --name repro --verbose
```

See `scanner --help` → **Debug** for the full flag documentation, and `CLAUDE.md` → **Debug Input** for the agent-facing workflow.
