# Monolith — Claude Code Guide

> Inherits general Swift standards from [workspace CLAUDE.md](../../.claude/CLAUDE.md).
> This file adds Monolith-specific rules only.

## Project Overview

Monolith is a Swift CLI tool that scaffolds iOS apps, Swift Packages, and Swift CLIs. It encodes patterns proven across Plantfolio and LumiKit.

**Version**: 0.1.0
**Swift**: 6.2, macOS 14+
**Dependencies**: ArgumentParser 1.7.0+

## Architecture

### Library + Executable Split

All source code lives in `MonolithLib` (library target). A thin `monolith` executable just calls `Monolith.main()`. This enables `@testable import MonolithLib` in tests.

```
Monolith/
  Package.swift
  Sources/
    MonolithLib/              # All source code (testable library)
      Monolith.swift          # @main ParsableCommand
      Commands/               # NewCommand, NewApp/Package/CLI, Version
      Config/                 # AppConfig, PackageConfig, CLIConfig, Feature enums
      Prompts/                # PromptEngine (readline), Validators
      Generators/
        App/                  # 21 generators (AppDelegate, SceneDelegate, TabBar, Theme, etc.)
        Package/              # 3 generators
        CLI/                  # 3 generators
        Shared/               # 7 generators (FileWriter, Gitignore, README, etc.)
      Utilities/              # ColorDeriver, ColorCodeGenerator, StringExtensions
    monolith/                 # Thin executable
      main.swift
  Tests/MonolithTests/        # Mirrors source structure
```

### Key Patterns

- **Pure function generators**: Each generator is `(Config) -> String` with no side effects
- **Synchronous ParsableCommand**: No async — all readline, FileManager, string ops
- **Feature flags drive generation**: `AppConfig.resolvedFeatures` auto-derives tabs, macCatalyst, darkMode
- **ColorDeriver**: HSB manipulation from 1 hex to 22 LMKTheme colors

### Commands

```bash
monolith new app       # Create iOS app (interactive or --no-interactive)
monolith new package   # Create Swift Package
monolith new cli       # Create Swift CLI
monolith version       # Print version
```

### App Features (14)

`swiftData`, `lumiKit`, `snapKit`, `lottie`, `darkMode`, `combine`, `localization`, `devTooling`, `rSwift`, `fastlane`, `claudeMD`, `licenseChangelog`, `tabs`, `macCatalyst`

Auto-derived: `tabs` (from non-empty tabs array), `macCatalyst` (from platform), `darkMode` (from lumiKit)

## Build & Test

```bash
swift build                           # Build
swift test                            # Run all tests
swift run monolith version            # Quick smoke test
swift run monolith new cli --name X --no-interactive  # Generate CLI
swift run monolith new package --name X --no-interactive  # Generate Package
swift run monolith new app --name X --no-interactive  # Generate App
```

## Testing

- **Swift Testing** framework (`@Test`, `#expect`, `@Suite`)
- Tests mirror source structure: `Tests/MonolithTests/{Commands,Config,Generators,Prompts,Utilities}/`
- Integration tests generate projects to temp dirs and verify file existence
- Generated output is string-based — test with `output.contains(...)` assertions

## SwiftFormat Rules

Pre-commit hook runs SwiftFormat. Key rules to follow when writing code:

- **`blankLinesAtStartOfScope`** — no blank line after opening `{` of structs, classes, enums, functions
- **`swiftTestingTestCaseNames`** — do NOT prefix `@Test` method names with `test` (e.g., use `func sampleModel()` not `func testSampleModel()`)
- **`redundantType`** — omit explicit type when it can be inferred (e.g., `var files = ["Package.swift"]` not `var files: [String] = ["Package.swift"]`)
