# Changelog

All notable changes to Monolith will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`--external-packages` + `--target-deps` on `monolith new app`** — ports the package generator's flags to the app generator so apps can wire arbitrary SPM frameworks (Prism, Causeway, any third-party library) outside the built-in registry. Same syntax as `monolith new package`: `--external-packages 'Name=url:requirement[:packageName];...'` (URL form) **or** `Name=path[:packageName]` (path form — for local-package development workflows where the adopting project sits alongside the library). Path-form entries emit `.package(name:, path:)` in `Package.swift` and `path:` in XcodeGen YAML. `--target-deps 'Product1,Product2,...'` wires products into the app target. Routing handles direct name match, longest-prefix match (`PrismCore` → `Prism`), single-external fallback, and explicit `:packageName` disambiguation. Externals override built-ins: `--external-packages 'LumiKit=path:../LumiKit'` replaces Monolith's default GitHub URL with the local path.
- **`--use-packages` flag** — built-in package registry. `--use-packages 'SnapKit,Lottie:5.0.0,LookinServer'` synthesizes `ExternalPackage` entries from `KnownPackages.registry` (no URL typing needed for the three registered packages). Optional `:version` per identifier overrides the registry default. Unknown identifiers raise a config-time error with a "did you mean…?" suggestion.
- **`KnownPackages` registry** — data-driven catalog of well-known third-party packages (`SnapKit`, `Lottie`, `LookinServer`). Each entry stores name, URL, default version, and optional platform conditional (LookinServer is iOS-only). Replaces the hardcoded `if config.hasSnapKit { packages.append(...) }` branches in `XcodeGenGenerator` + `SPMAppGenerator`. Adding a new well-known package is now a registry entry, not a generator change.
- **`AppConfig.validate()`** — new method, no-op when external packages aren't used. Throws `AppConfigError` for name collisions with the app target or unconsumed externals.
- **`ExternalPackage.parse(_:)` + `ExternalPackage.parseUsePackages(_:)`** — extracted from `NewPackageCommand` to `Config/Feature.swift` so all commands share one parser surface. Cuts ~40 lines of duplication. Surfaces typed errors that commands map to `ArgumentParser.ValidationError`.

### Changed
- **`snapKit` and `lookin` removed from `AppFeature`** — replaced by the `KnownPackages` registry (consumed via `--use-packages`). `--features snapKit,lookin` still works for one minor version via a deprecation shim that auto-translates to `--use-packages` and emits a stderr warning. Removed entirely in v0.4. The principle: `--features` is for code-shaping integrations (LumiKit's theme + `LMKNavigationController` + LMKLogger; Lottie's `LottieHelper.swift` template); the registry is for "just wire the dep" cases.
- **`AppConfig.hasSnapKit` and `hasLookin`** — now read from `externalPackages` instead of `resolvedFeatures`. The property names stay (downstream consumers like `ReadmeGenerator` still want them) but the source of truth moved.
- **`AddableFeature.snapKit` + `AddableFeature.lookin`** — unchanged for now. The `monolith add snapKit` retrofit workflow keeps working for existing projects. v0.4 cleanup will route them through `KnownPackages.registry` too.

### Tests
- 38 new tests across `AppConfigTests`, `XcodeGenGeneratorTests`, `SPMAppGeneratorTests`. Coverage: external-packages validation, single-external multi-product happy path, multi-external happy path, local-path parsing + emit, URL-form regression check, `--use-packages` registry lookup, version override, unknown-identifier error, platform conditional emit, deprecation shim. Total: 717 → 755 tests, 68 → 69 suites, zero regressions.

## [0.2.0] - 2026-05-20

### Added
- **`LocalizationAuditGenerator`** — emits `Scripts/localization/audit_strings.py` whenever the `localization` feature is on (both `new app` and `add localization`). Flags missing locales, untranslated state, placeholder-arity mismatches between locales, and the silent-fail Swift `\(...)` interpolation bug from workspace lessons.md
- **`make audit-strings` Makefile target** — wired automatically when `localization` + `devTooling` are both selected. `make check` invokes it alongside SwiftLint and SwiftFormat
- **`ShellRunner` utility** — centralized wrapper around `Process()` with three entry points (`run`, `runDiscardingOutput`, `runCapturingStdout`). Replaces 14 hand-rolled `Process()` setups across `XcodeGenRunner`, `PackageResolver`, `ProjectOpener`, `ToolChecker`, `FileWriter.gitInit` + `gitAuthorName`
- **`UISymbols` enum** — named constants for ✓ ✗ ⚠ ↻ ─ ↑. Replaces inline `"\u{2713}"` / literal `"✓"` mix
- **`SignalHandler` utility** — registers a SIGINT handler that removes the partial output directory if the user hits Ctrl-C mid-generation. Wired into `new app`, `new package`, `new cli`. The wizard's raw-mode `0x03` path now `raise(SIGINT)`s instead of `exit(0)`-ing, so the same cleanup runs even when interrupted during the wizard
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
- **LumiKit version bumped** 0.2.0 → 0.8.0. Generated code uses `LMKThemeManager.shared.apply(theme)` instead of `.setTheme(theme)`
- **Swift 6 concurrency in templates** — Added `@MainActor` to generated `DataPublisher` class, `SWIFT_APPROACHABLE_CONCURRENCY` and `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` to XcodeGen settings
- **Makefile generator** — Added `PROJECT` variable and `-project $(PROJECT)` flag for xcodeProj/xcodeGen. Uses `Defaults.simulatorDestination` with `OS=` version. Removed `-skipPackagePluginValidation`
- **License changed from MIT to Apache 2.0** (Monolith's own `LICENSE` file)
- **SwiftLint `type_name.max_length` relaxed** — warning: 40→60, error: 50→70 (own config and generated configs)
- **SwiftFormat config updates** — `--commas always` → `--trailing-commas collections-only`, `--enable redundantProperty` → `--enable redundantVariable` (renamed rule), added `--disable wrapPropertyBodies`
- **Removed `Sendable` conformance from all internal types** — Not needed since they don't cross isolation boundaries
- **Trailing commas removed from function calls** throughout codebase (consistent with `--trailing-commas collections-only`)
- **`ProjectOpener` rewritten** — Uses project name for `.xcodeproj` filename, fallback logic checks for `project.yml` when `.xcodeproj` doesn't exist
- **README and CLAUDE.md generators** — Build instructions use `make build`/`make test` for xcodeProj/xcodeGen instead of raw `xcodebuild` commands
- **Error diagnostics surfaced from shell-outs** — previously silent `catch { return false }` paths in `XcodeGenRunner`, `ProjectOpener`, `FileWriter.gitInit`, etc. now print `error.localizedDescription` and any captured stderr through `UISymbols.warn`. Users can finally tell "tool missing" from "permission denied" from "exit 1 with stderr message"

### Tests
- **`FileWriterTests`** (11 tests) — covers `writeFile` with nested dirs, executable bit, `gitInit` happy path + `hasGitHooks` + nonexistent dir, `gitAuthorName`, `resolveOutputPath`. Previously zero coverage on a 286-line file every integration test depends on
- **`ProjectYamlEditorTests`** (20 tests) — covers every editor (`addPackage`, `addTargetDependency`, `enableMacCatalyst`, `addWidgetTarget`, `wireAppForWidget`, end-to-end widget flow). Confirms idempotency and failure-mode messages. Previously zero coverage on 290 lines of hand-rolled YAML parsing
- **`ShellRunnerTests` + `SignalHandlerTests`** (15 tests) — exercise capture/discard/launch-failure paths, mergeStderr, cwd, partial-output cleanup
- **`PromptEngineTests`** (16 tests) — `parseFeatures` across all three feature enums, `parseTabs`, `isBackCommand`
- **`WizardEngineTests`** (9 tests) — navigation helpers (`visibleIndex`, `visibleCount`, `previousVisibleIndex`) under hidden-step scenarios. Helpers made `internal` so the state machine can be tested without a TTY
- **`LocalizationAuditGeneratorTests`** (8 tests) — including a Python `ast.parse` round-trip that catches escape-sequence regressions before they SyntaxWarning in user terminals
- **`MakefileGeneratorTests`** — added two cases for the new `hasLocalization` switch (audit-strings target wired into `check` + `help`; omitted otherwise)
- **Generator output sanity checks** (8 tests in `IntegrationTests`) — structural assertions covering YAML indentation of `preBuildScripts` / `postCompileScripts`, the `LumiKit` → `product: LumiKitUI` line pair, test-source-file ordering before xcodegen, `validate-app-icon.sh` POSIX permissions = 0o755, `MainTabBarController` `init()` declaration, and `@MainActor` isolation on the Core Data stack + `TestContext`. Each backed by a comment naming the regression it prevents
- **Total test count**: 542 → 631

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
