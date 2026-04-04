---
id: '260404-0ZSXSQG'
title: Remove all scanline references and rename config files
author: Dominic Rodemer
created_at: '2026-04-04T09:02:53.512537Z'
status: open
labels:
- refactoring
---

The project was originally called "scanline" and has been renamed to "scanner". There are still leftover references to the old name throughout the codebase.

## Tasks

- Search all source files for "scanline" references (strings, comments, variable names)
- Rename config file path from `~/.scanline.conf` to `~/.scanner.conf`
- Update any user-facing strings that still mention "scanline"
- Ensure backward compatibility or migration path for users with existing `~/.scanline.conf` files
- Update CLAUDE.md if it references the old config file name
