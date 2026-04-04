//
//  main.swift
//  scanner
//
//  Created by Dominic Rodemer on 03.04.26.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import libscanner

let appController = AppController(arguments: CommandLine.arguments)
appController.go()

CFRunLoopRun()
