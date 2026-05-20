# Monolith — Claude Code Guide

> Swift CLI that scaffolds iOS apps, Swift Packages, and Swift CLIs. Pure Swift, no UIKit, no simulator needed for tests.

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
      Commands/               # New{App,Package,CLI}, List, Add, Doctor, Completions, Version
      Config/                 # AppConfig, PackageConfig, CLIConfig, Feature, Preset, ConfigFile, AddableFeature, DependencyVersion
      Prompts/                # PromptEngine (readline), WizardEngine, WizardStep, Validators
      Generators/
        App/                  # 21 generators (AppDelegate, SceneDelegate, TabBar, Theme, etc.)
        Package/              # 3 generators
        CLI/                  # 3 generators
        Shared/               # 10 generators (SwiftLint, SwiftFormat, Makefile, etc.)
      Utilities/              # FileWriter, ColorDeriver, ToolChecker, OverwriteProtection,
                              # ProjectDetector, ProjectOpener, PackageResolver
    monolith/                 # Thin executable
      main.swift
  Tests/MonolithTests/        # 416 tests, 53 suites — mirrors source structure
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
monolith list features # List available features (--type app|package|cli)
monolith add <feature> # Add feature to existing project (--path, --dry-run, --bundle-id for widget)
monolith doctor        # Check tool availability
monolith completions   # Generate shell completions (zsh|bash|fish)
monolith version       # Print version
```

### New Flags on `new` Commands

`--preset` (minimal/standard/full), `--force` (overwrite protection), `--open` (open in Xcode), `--resolve` (swift package resolve), `--save-config`/`--load-config` (JSON config files), `--license` (mit/apache2/proprietary — defaults: app=proprietary, package=mit, cli=apache2)

### Package-only flags for multi-target frameworks

- `--package-deps` (comma-separated): cross-cutting deps auto-merged into every target's dependency list. Resolves like `--target-deps`.
- `--xctest-targets` (comma-separated): targets that should link XCTest as a system framework. For test-utility libraries imported by adopter test targets (e.g. Causeway's `CausewayTesting`).
- `--target-resources` (`"Target:dir1,dir2;..."`): emits `resources: [.process(...)]` per target.
- `--external-packages` (`"Name=url:requirement[:packageName];..."`): declares external SPM packages outside the built-in registry (SnapKit, Lottie, LumiKit*). `requirement` is verbatim SPM (`from: "0.1.0"`, `branch: "main"`).

### App Features (27)

Data: `swiftData`, `coreData`, `cloudKit`, `cloudKitSharing`
UI / third-party: `lumiKit`, `snapKit`, `lottie`, `lookin`, `darkMode`, `combine`
System: `notifications`, `deepLinks`, `spotlight`, `deferredLaunchWork`, `widget`, `localization`
App Store hygiene: `privacyManifest`, `appIconValidation`
Tooling: `devTooling`, `gitHooks`, `coreDataAuditHook`, `claudeMD`, `licenseChangelog`
Legacy (XcodeGen only): `rSwift`, `fastlane`
Auto-derived: `tabs` (from non-empty tabs array), `macCatalyst` (from platform), `darkMode` (from lumiKit), `coreDataAuditHook` (from coreData/swiftData + cloudKit + gitHooks)

Not recommended: `rSwift` (XcodeGen only, inactive development — Xcode 15+ has native type-safe resources), `fastlane` (XcodeGen only, prefer Makefile or Xcode Cloud)

### `monolith add <feature>` — retrofit features into an existing project

Two tiers, both invoked as `monolith add <feature> [--path <dir>] [--dry-run]`:

- **Tier 1 — pure file writes (any project system)**: `devTooling`, `gitHooks`, `claudeMD`, `licenseChangelog`, `privacyManifest`, `appIconValidation`
- **Tier 2 — app projects only**: `localization`, `macCatalyst`, `lottie`, `snapKit`, `lookin`, `widget`. On XcodeGen projects, the command edits `project.yml` in place (idempotent — re-running is a no-op); re-run `xcodegen generate` afterward. On `.xcodeproj` projects, the source files are written but the user must perform manual integration steps (target membership, Add Package, entitlements) which the command prints.

`widget` accepts `--bundle-id <prefix>` to compute the App Group identifier. Without it, defaults to `com.example.<appname>`.

The other 15 features (`swiftData`, `coreData`, `cloudKit`, `cloudKitSharing`, `lumiKit`, `darkMode`, `combine`, `tabs`, `notifications`, `deepLinks`, `spotlight`, `deferredLaunchWork`, `coreDataAuditHook`, `strictConcurrency`, `defaultIsolation`) require editing existing `AppDelegate.swift`/entitlements/Info.plist/Package.swift in ways that depend on user-modified content. Best path: re-scaffold with the new feature set into a temp dir and cherry-pick the diff.

### Generator no-ops

- `strictConcurrency` (Package + CLI feature): no-op at `swift-tools-version: 6.2`. The legacy `.enableExperimentalFeature("StrictConcurrency")` shim is obsolete; strict concurrency is the language default. Flag still accepted (config backwards-compat) but generates no `swiftSettings` entry. CLI emits a stderr warning when set.

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

## SwiftLint & SwiftFormat

Run `make check` to verify both. Pre-commit hook (`Scripts/git-hooks/pre-commit`) runs them automatically.

Generated projects inherit the same SwiftLint / SwiftFormat config as Monolith itself (see `.swiftlint.yml`, `.swiftformat`). Notable settings:
- Swift 6.2, `--trailing-commas collections-only`, `--self remove`, `--indent 4`
- Force unwrapping and force casting are warnings (not allowed in any committed code)
- Trailing commas mandatory on collection literals
- `@Test` method names should NOT be prefixed with `test`

---

*Optimized for Claude Code.*
