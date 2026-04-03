# Changelog

All notable changes to Monolith will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-04-03

### Added
- **`xcodeProj` project system** — New default for iOS apps. Generates a committed `.xcodeproj` by running XcodeGen once then removing `project.yml`, giving users a standard Xcode project with no XcodeGen dependency. New `XcodeGenRunner` utility handles the subprocess
- **`LookinServer` AppFeature** — iOS-only UI debugging dependency (v1.2.8). Platform-conditional in both SPM (`.when(platforms: [.iOS])`) and XcodeGen (`platforms: [iOS]`)
- **`--license` flag** on all `new` commands — Supports `mit`, `apache2`, `proprietary` with per-type defaults (app=proprietary, package=MIT, CLI=Apache 2.0). New `LicenseType` enum with full Apache 2.0 and Proprietary license templates
- **SwiftLint and SwiftFormat Xcode build phase scripts** — XcodeGen-generated projects include `preBuildScripts` (SwiftFormat) and `postCompileScripts` (SwiftLint) with ARM64 Homebrew PATH detection
- **Next steps in generated output** — All three project types print actionable next steps to console after generation. App and package READMEs include a "Next Steps" section
- **`Defaults` constants enum** — Centralized `primaryColor`, `deploymentTarget`, `simulatorOS`, `simulatorDevice`, `simulatorDestination`, `defaultPlatform`. Eliminates scattered magic strings across commands and generators
- **`ProjectDetector` detects `.xcodeproj` bundles** — Can now detect committed Xcode projects (not just `project.yml` or `Package.swift`)
- **XcodeGen build settings** — `GENERATE_INFOPLIST_FILE`, `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`
- **`DerivedData/` added to generated `.gitignore`**

### Changed
- **Generators refactored to multiline string literals** — Converted `lines.append(...)` blocks to `"""` strings across 12+ generators (AppDelegate, SceneDelegate, TabBar, AppConstants, ViewController, DarkMode, Localization, Theme, CLIPackageSwift, PackageSwift, SPMApp). Improves template readability
- **Generated code aligned with SwiftFormat rules** — Removed blank lines after opening `{`, added `final` to generated classes, sorted imports alphabetically
- **LumiKit version bumped** 0.2.0 → 0.4.0. Generated code uses `LMKThemeManager.shared.apply(theme)` instead of `.setTheme(theme)`
- **Swift 6 concurrency in templates** — Added `@MainActor` to generated `DataPublisher` class, `SWIFT_APPROACHABLE_CONCURRENCY` and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` to XcodeGen settings
- **Makefile generator** — Added `PROJECT` variable and `-project $(PROJECT)` flag for xcodeProj/xcodeGen. Uses `Defaults.simulatorDestination` with `OS=` version. Removed `-skipPackagePluginValidation`
- **License changed from MIT to Apache 2.0** (Monolith's own `LICENSE` file)
- **SwiftLint `type_name.max_length` relaxed** — warning: 40→60, error: 50→70 (own config and generated configs)
- **SwiftFormat config updates** — `--commas always` → `--trailing-commas collections-only`, `--enable redundantProperty` → `--enable redundantVariable` (renamed rule), added `--disable wrapPropertyBodies`
- **Removed `Sendable` conformance from all internal types** — Not needed since they don't cross isolation boundaries
- **Trailing commas removed from function calls** throughout codebase (consistent with `--trailing-commas collections-only`)
- **`ProjectOpener` rewritten** — Uses project name for `.xcodeproj` filename, fallback logic checks for `project.yml` when `.xcodeproj` doesn't exist
- **README and CLAUDE.md generators** — Build instructions use `make build`/`make test` for xcodeProj/xcodeGen instead of raw `xcodebuild` commands

### Fixed
- **`GENERATE_INFOPLIST_FILE: YES`** added to app template — prevents missing `CFBundleIdentifier` build error
- **GitHooksGenerator**: removed `--quiet` from swiftformat — was suppressing lint output in pre-commit hook, making failures silent
- **Missing `OS=` in package simulator destinations** — Package README/CLAUDE.md generators had bare `platform=iOS Simulator,name=iPhone 17` without `OS=` version

### Removed
- **SPM as a project system for iOS apps** — `ProjectSystem.appOptions` now only includes `xcodeProj` and `xcodeGen` (SPM `executableTarget` can't handle signing, entitlements, or capabilities)

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

[0.2.0]: https://github.com/Luminoid/Monolith/releases/tag/0.2.0
[0.1.0]: https://github.com/Luminoid/Monolith/releases/tag/0.1.0
