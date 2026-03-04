# Changelog

All notable changes to Monolith will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-03

### Added

#### Commands
- **`new app`** — Scaffold iOS apps with interactive wizard or `--no-interactive` flags
- **`new package`** — Scaffold Swift Packages with multi-target support
- **`new cli`** — Scaffold Swift CLI tools with optional ArgumentParser
- **`list features`** — List available features filtered by project type (`--type app|package|cli`)
- **`add <feature>`** — Add features to existing projects (`devTooling`, `gitHooks`, `claudeMD`, `licenseChangelog`)
- **`doctor`** — Check availability of required and optional tools
- **`completions`** — Generate shell completions (zsh, bash, fish)
- **`version`** — Print current version

#### Interactive Wizard
- Full-page guided setup with step progress (Step N of M)
- Summary of previous answers displayed on each page
- Back navigation (press `↑` or type `back`) with answer preservation
- Native arrow key support via macOS editline (`CEditLine` system library)
- Confirmation page before generating

#### iOS App Features (15)
- **SwiftData** — `@Model`, `ModelContainer` setup, in-memory test helpers
- **LumiKit** — Package dependency with 22-color `LMKTheme` generation from primary color via `ColorDeriver`
- **SnapKit** — Programmatic Auto Layout dependency
- **Lottie** — Animation dependency with optional `LumiKitLottie` integration
- **Dark Mode** — Standalone `AppTheme` with adaptive `UIColor` patterns (auto-enabled with LumiKit)
- **Combine** — Publisher/subscriber boilerplate and async Task patterns
- **Localization** — String Catalog + `L10n` helper with `String(localized:)`
- **Dev Tooling** — SwiftLint, SwiftFormat, Makefile, Brewfile (one toggle, four files)
- **Git Hooks** — Pre-commit hook (lint + format check on staged files)
- **R.swift** — Code generation + Mintfile (XcodeGen only)
- **Fastlane** — Gemfile, Appfile, Fastfile (XcodeGen only)
- **CLAUDE.md** — Project-specific Claude Code guide following ecosystem template
- **License + Changelog** — MIT license and Keep a Changelog template
- **Tabs** — Tab bar controller with nav-controller-per-tab pattern (auto-enabled from `--tabs`)
- **Mac Catalyst** — Window config and menu bar (auto-enabled from `--platforms macCatalyst`)

#### iOS App Project Systems
- **SPM** — `Package.swift` with `.executableTarget` (default)
- **XcodeGen** — `project.yml` with `xcodegen generate`

#### Package Features (6)
- Strict concurrency, default isolation (`MainActor` per target), dev tooling, git hooks, CLAUDE.md, license + changelog
- Multi-target support with inter-target dependencies (`--target-deps`)
- Multi-platform support (`--platforms "iOS 18.0,macOS 15.0,macCatalyst 18.0"`)

#### CLI Features (6)
- ArgumentParser dependency, strict concurrency, dev tooling, git hooks, CLAUDE.md, license + changelog

#### Generation Options
- **`--preset`** — Pre-select features: `minimal` (none), `standard` (devTooling, gitHooks, claudeMD), `full` (all)
- **`--force`** — Overwrite existing project directory
- **`--open`** — Open in Xcode after generation
- **`--resolve`** — Run `swift package resolve` after generation
- **`--save-config` / `--load-config`** — Save and reuse project configurations as JSON
- **`--output`** — Custom output directory
- **`--dry-run`** — Preview generated files without writing

#### Utilities
- **ColorDeriver** — HSB manipulation from 1 hex color to 22 `LMKTheme` colors
- **ToolChecker** — Verify tool availability (`swift`, `git`, `swiftlint`, `swiftformat`, `xcodegen`, `mint`, `fastlane`)
- **OverwriteProtection** — Prevent accidental directory overwrites (respects `--force`)
- **ProjectDetector** — Detect existing project type in a directory
- **ProjectOpener** — Open generated projects in Xcode
- **PackageResolver** — Run `swift package resolve` on generated projects
- **FileWriter** — Write files with progress reporting and directory creation

#### Infrastructure
- Swift 6.2, macOS 14+
- `MonolithLib` (testable library) + `monolith` (thin executable) architecture
- Pure function generators: `(Config) -> String` with no side effects
- ArgumentParser 1.7.0+ dependency
- 69 source files, 45 test files
- 378 tests across 52 suites (Swift Testing)
- MIT License

[0.1.0]: https://github.com/Luminoid/Monolith/releases/tag/0.1.0
