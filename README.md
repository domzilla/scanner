scanner
========

scanner is a command-line scanning utility for macOS. It was originally built for a quirky archiving system, where every document (bills, tax forms, etc.) is scanned and categorized into folders. Rather than use a traditional scanning program that requires time consuming pointing and clicking, scanner lets you easily scan from a command prompt.

scanner supports many different purposes and options. Some of the things you can do with scanner are:

* Run scanner as part of a script
* Scan batches of documents
* Scan from the document feeder or flatbed
* Scan in various formats, sizes, and modes all driven from command line options
* Provide defaults in a config file (~/.config/scanner/scanner.conf)


Here are some example command lines:

```
scanner -duplex taxes
scanner -flatbed -jpeg photo
```
   
You can see all of scanner's options by typing:

```
scanner -help
```

## Building scanner

```bash
xcodebuild -scheme "scanner" -destination "platform=macOS" build
```

## libscanner

scanner is structured with a static library (libscanner) that contains all core logic, and a separate command-line target that links against it. libscanner can be embedded in any application that wants to support scanner's functionality.

## Contributing to scanner

If you're interested in making a change, fix, or enhancement to scanner, please do! I'd appreciate a heads up on any bigger changes, and I'm happy to review any PRs.
