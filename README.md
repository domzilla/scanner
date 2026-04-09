# scanner

A command-line document scanning utility for macOS, built on the ImageCaptureCore framework.

scanner lets you scan documents directly from the terminal — no GUI required. It supports document feeders and flatbed scanners, multiple output formats, duplex scanning, batch mode, and more.

## Installation

```bash
brew tap domzilla/homebrew-tap
brew install scanner
```

## Usage

```bash
scanner [options]
scanner list [options]
```

Scanned files are saved to the current directory.

### Examples

```bash
# Scan a document to PDF (default)
scanner

# Scan both sides of each page
scanner --duplex

# Scan to JPEG with a custom filename
scanner --name invoice --format jpeg

# Scan from the flatbed in black and white
scanner --input flatbed --color mono

# Scan a legal-size page at 300 dpi
scanner --size legal --resolution 300

# Batch mode — pause after each page for more
scanner --batch

# List available scanners
scanner list
```

### Options

#### Scanning
| Flag | Description |
|---|---|
| `-i`, `--input <source>` | Scan source: `feeder` (default), `flatbed` |
| `-d`, `--duplex` | Scan both sides of each page |
| `-b`, `--batch` | Pause after each page to allow additional pages |

#### Output Format
| Flag | Description |
|---|---|
| `-f`, `--format <format>` | File format: `pdf` (default), `jpeg`, `tiff`, `png` |

#### Page Size
| Flag | Description |
|---|---|
| `-s`, `--size <size>` | Page size: `a4` (default), `letter`, `legal` |

#### Image
| Flag | Description |
|---|---|
| `-c`, `--color <mode>` | Color mode: `color` (default), `mono` |
| `-r`, `--resolution <dpi>` | Minimum resolution in dpi (default: 150) |
| `--rotate <degrees>` | Rotate scanned images by degrees (default: 0) |

#### Output
| Flag | Description |
|---|---|
| `-n`, `--name <name>` | Custom filename (without extension) |

#### Scanner
| Flag | Description |
|---|---|
| `--scanner <name>` | Use a specific scanner by name (substring match) |
| `-e`, `--exactname` | Require exact name match with `--scanner` |

#### General
| Flag | Description |
|---|---|
| `--verbose` | Enable verbose logging |
| `--version` | Print version and exit |

#### Debug
| Flag | Description |
|---|---|
| `--debug-input <path>` | Development/testing only. Skip the hardware scanner and feed the given image file (or directory of images) into the normal output pipeline. See below. |

`--debug-input` is intended for reproducing bugs against an existing scan or iterating on output changes without running the scanner every time. It runs the exact same pipeline used for real scans — rotation, format conversion, PDF assembly, MRC — so the resulting file is byte-identical to what you'd get from a live scan of the same image.

- **Single file:** `scanner --debug-input page.jpg` — treats the file as a one-page input.
- **Directory:** `scanner --debug-input /tmp/pages` — uses every image file (jpg/jpeg/png/tif/tiff) in the directory, sorted lexicographically by filename, as pages of a single multi-page output.
- Inputs are copied to a temp staging directory before processing, so `--rotate` will not mutate your originals.
- Combine with any other output flag: `scanner --debug-input /tmp/pages --no-mrc --name repro` writes `repro.pdf` in the current directory using the no-MRC pipeline.

### Config File

Default options can be set in `~/.config/scanner/scanner.conf`, one flag per line:

```
--format jpeg
--resolution 300
--size letter
```

CLI arguments override config file values.

## Building

```bash
cd src
xcodebuild -scheme scanner -destination "platform=macOS" build
```

## License

MIT
