//
//  main.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import libscanner

let (options, configuration) = CLI.parseArguments(Array(CommandLine.arguments.dropFirst()))
let appController = AppController(options: options, configuration: configuration)
appController.go()

CFRunLoopRun()
