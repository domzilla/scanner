---
id: '260404-0ZSY40N'
title: Write a good scanner -h help menu
author: Dominic Rodemer
created_at: '2026-04-04T09:02:54.228627Z'
status: closed
labels:
- feature
---


The `scanner -h` help output is the single source of truth for users and AI agents (per CLAUDE.md). It needs to be clear, complete, and well-organized.

## Tasks

- Review the current `commandList()` method in `CLI.swift`
- Write a comprehensive help menu covering all flags and options
- Group options logically (output, scanning, OCR, etc.)
- Include brief usage examples in the help output
- Ensure every supported flag and option is documented
- Follow conventions of well-known CLI tools (e.g., `ffmpeg`, `imagemagick`)
