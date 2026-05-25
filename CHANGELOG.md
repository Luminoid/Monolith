# Changelog

All notable changes to Monolith will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **`--locales` flag on `new app`** — comma-separated locale codes (`'en,zh-Hans,es'`) for the generated `Localizable.xcstrings` catalog. First locale is the source language. Non-source entries start at `state: "new"` so the localization audit surfaces them as outstanding translation work. Default remains `["en"]` for back-compat; the workspace convention is `'en,zh-Hans,es'` (matches Petfolio).
- **`--category` flag on `new app`** — App Store category (`public.app-category.productivity`, etc.). Required for Mac App Store distribution. Defaults to `public.app-category.utilities`. Written into the Info.plist as `LSApplicationCategoryType`, not as an `INFOPLIST_KEY_*` build setting.
- **`make build-clean` target** — runs `xcodebuild clean build` to verify zero-warning state. The workspace rule is that incremental builds skip unchanged files and hide their warnings; `clean build` is the only path that reliably surfaces them.
- **3-variant AppIcon skeleton** — `AssetGenerator.generateAppIconContents()` now emits three entries: no-appearance (light), `luminosity: dark`, and `luminosity: tinted` for the iOS 18 monochrome variant. Adopters drop PNGs into each slot instead of restructuring the asset catalog later.
- **Persistence demo test** — when SwiftData is enabled, `TestGenerator.generateAppTest` emits one `@Test` that exercises `TestContext.makeContainer()` + `TestDataFactory.makeSampleItem(...)` end-to-end. Adopters get a green test signal on first `make test`, and the helper APIs are referenced rather than dead code.
- **`PharosKit-aware ColorCodeGenerator.varColorPropertyLumiKit`** — emits compact one-liner colors via LumiKit 0.9.0's `UIColor.lmk_dynamic(lightHex: 0x..., darkHex: 0x...)`. Generated themes drop from ~160 lines to ~70 (≈56% reduction). Requires `DependencyVersion.lumiKit = "0.9.0"`.
- **`InfoPlistGenerator.Options.urlIdentifier`** — emits `CFBundleURLName` (reverse-DNS) inside `CFBundleURLTypes`. `AppProjectGenerator` defaults it to `config.bundleID` so system tools can disambiguate URL handler identity if multiple apps register the same scheme.
- **`InfoPlistGenerator.Options.applicationCategoryType`** — emits `LSApplicationCategoryType` in the Info.plist. Plumbed through from the new `--category` flag.
- **Standard bundle-metadata keys in Info.plist** — `CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER)`, `CFBundleVersion`, `CFBundleShortVersionString`, `CFBundleName`, `CFBundleDisplayName`, `CFBundleExecutable`, `CFBundleDevelopmentRegion`, `CFBundleInfoDictionaryVersion`, `CFBundlePackageType`, `LSRequiresIPhoneOS`. These were previously auto-merged by `GENERATE_INFOPLIST_FILE = YES`; with `NO` (see Changed) the hand-written file declares them explicitly. Without them the simulator refuses to install the .app with "Missing bundle ID".
- **`UIColor.lmk_dynamic(lightHex:darkHex:alpha:)` + `UIColor(lmk_hex: UInt32, alpha:)`** in LumiKit 0.9.0 — compile-time-validated hex initializer + trait-aware light/dark color factory used by the compact theme generator. (Cross-repo: shipped in LumiKit 0.9.0; consumed here.)

### Changed
- **`GENERATE_INFOPLIST_FILE: NO`** in the generated XcodeGen YAML when a hand-written `INFOPLIST_FILE` is also declared. The previous `YES + INFOPLIST_FILE` combination made Xcode merge auto-generated keys on top of the hand-written file with confusing precedence; now there's exactly one source of truth (the hand-written file).
- **`LSApplicationCategoryType` lives in the Info.plist**, not as an `INFOPLIST_KEY_*` build setting in `project.yml`. With `GENERATE_INFOPLIST_FILE: NO` the build-setting form wasn't reliably merged; the in-file form is unambiguous.
- **`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` explicit** — set to `AccentColor` alongside the existing `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` so the asset wiring is visible in the pbxproj instead of relying on Xcode defaults.
- **`SceneDelegate` Mac Catalyst block delegates to `MacWindowConfig.configure(_:)`** — previously inlined the titlebar / `sizeRestrictions` body, which was the third copy of the same `600/800/1200/1500` magic-number set in the workspace (`AppConstants`, `MacWindowConfig`, the inline body). Now there's exactly one canonical definition (in `AppConstants.MacWindow`), `MacWindowConfig.configure` reads from it, and `SceneDelegate` calls `MacWindowConfig.configure(windowScene)`.
- **`DesignSystemGenerator` no longer emits `enum MacWindow`** — the canonical home is `AppConstants.MacWindow`. Re-emitting under `DesignSystem` created two sources of truth that adopters could read from inconsistently.
- **`SceneDelegate` SwiftData guard splits binding form** — when tabs are enabled the guard binds `let modelContainer = ...` and forwards it to `MainTabBarController(modelContainer:)`. When tabs are absent the placeholder `ViewController()` consumes no container, so the guard uses `!= nil` instead of `let _ = ...` (which trips SwiftLint's `unused_optional_binding` rule). Both forms preserve the existence check; only the binding form differs.
- **`disableTestParallelism` gated tighter** — now `(coreData || swiftData) && cloudKit`, not `coreData || swiftData`. Plain SwiftData (no CloudKit, no shared repository) doesn't have the singleton race that the flag mitigates; pinning the worker count at 1 cost serial test execution for no benefit. CloudKit-backed persistence keeps the flag.
- **`-quiet` on every `xcodebuild` invocation** in generated Makefiles — matches the workspace convention (Plantfolio / Petfolio / LumiKit / Prism all use it). Per-file compile output stays out of the recipe; warnings and errors still surface.
- **`ColorDeriver` secondary / tertiary use an analogous palette** (±30° hue shift), not a triadic one (+150° / +210°). Triadic produced jarring complementary colors that fought the seed (a violet primary getting an amber-gold secondary and a green tertiary). Analogous shifts read as "lighter / darker / cooler / warmer variants of the primary" — what most apps want from a derived palette.
- **Generated `Localizable.xcstrings` is multi-locale** — when `--locales` declares more than one, each key emits a `localizations` entry per locale. Source-language entries are `state: "translated"`; non-source entries are `state: "new"` so the localization audit flags them as outstanding work.
- **Test helpers `@testable import` the app module** — `TestContext.swift` and `TestDataFactory.swift` reference `SampleItem`, which is `internal` by default. The previous scaffold omitted the import and compiled only because the test bundle's suite was empty; adding the persistence demo test exposed the latent "cannot find 'SampleItem' in scope" bug.
- **`AsyncService.swift` uses `for-in` over `forEach`** — modern Swift preference; better for breakpoints and avoids closure overhead.
- **`KnownPackages.registry` is the single source of truth for every well-known SPM package** — URL, default version, SPM package name, exposed products, platform conditional, and required-platform floors all live on one `Entry` per package. `PackageSwiftGenerator.knownPackageDependency` / `knownProductDependency`, `SPMAppGenerator`'s built-in feature wiring (LumiKit / Lottie URLs), `XcodeGenGenerator`'s `packages:` block, `CLIPackageSwiftGenerator`'s ArgumentParser wiring, `AddFeatureHandlers.PackageSpec.lottie`, and `PackageConfig.mergingRequiredPlatforms` all read from one registry instead of duplicating switches. `KnownPackages.Entry.exposeViaUsePackages` filters the user-facing `--use-packages` allow-list (`SnapKit`, `Lottie`, `LookinServer`) from internal-only entries (`LumiKit`, `ArgumentParser`) that the CLI wires through feature flags or executable-target inference. `KnownPackages.entryOwning(product:)` resolves multi-product packages (`LumiKitCore` → LumiKit entry). The previous `KnownDependencyPlatforms` enum is gone — its data folded into `Entry.platformFloors`.
- **`AppConfig` gains `hasFastlane`, `hasRSwift`, `hasClaudeMD`, `hasLicenseChangelog` accessors** — `AppProjectGenerator.writeInfraFiles`, `FileWriter.printDryRun`, and `ReadmeGenerator` previously reached into `config.resolvedFeatures.contains(...)` directly while the rest of the same file used `config.hasLumiKit` / `hasDevTooling` / `hasWidget`. The asymmetry didn't survive the audit. All four legacy / sidecar features now have parallel accessors.
- **`ValidationBridge.bridge(_:)` collapses the four `do { ... } catch { throw ValidationError(error.description) }` blocks** — three in `NewAppCommand` (`parseUsePackages` / `parseExternalPackages` / `config.validate()`), one in `NewPackageCommand`. The bridge sits next to the commands so the `ArgumentParser` import stays out of `Config/`, and catches via `as CustomStringConvertible` so any throwing config / parser type with a user-facing `description` flows through without a typed-throws signature on the caller. `PackageConfig.validate()` and its helpers (`validateDependencyName`, `detectCycles`) gain `throws(PackageConfigError)` typed-throws signatures to match `AppConfig.validate()`'s.
- **`ColorCodeGenerator` moved from `Utilities/` to `Generators/App/`** — both consumers (`ThemeGenerator`, `DarkModeGenerator`) live under `Generators/App/`, and the file emits Swift source code rather than providing a non-emitting helper. `Utilities/` is now the home for non-emitting infrastructure (ShellRunner, SignalHandler, etc.).
- **Em-dash parenthetical separators replaced with colons / semicolons** in user-facing CLI strings and code comments — workspace rule disallows the `key — explanation` mid-sentence pattern in prose, comments, commits, and docs. Affected: `OverwriteProtection` (overwrite warning), `ToolChecker.formatStatus` (tool version formatting now uses `(version)`), `New{App,Package,CLI}Command` (reserved-word error + license-display format + `strictConcurrency` no-op comment), `PromptEngine.wizardTabs` (SF Symbols format hint), `AddFeatureHandlers` (`alreadyPresent` cycle message), and `NewPackageCommand.parseExternalPackages` doc comment. Decorative title dividers (`Monolith — New iOS App`) preserved per the rule's carve-out.

### Removed
- **`--features snapKit` and `--features lookin`** — removed per the v0.3 deprecation. Both packages moved to the `--use-packages` registry in v0.3; the auto-translating shim is gone. The CLI now raises a `ValidationError` listing the migration: `snapKit → --use-packages SnapKit`, `lookin → --use-packages LookinServer`. `AppFeature.deprecatedPackageFeatureNames` is replaced by `KnownPackages.removedFeatureAliases` (same data, used to produce the error).
- **`monolith add snapKit` and `monolith add lookin`** — removed. Existing projects retrofit SnapKit / LookinServer via Xcode's native Add Package flow (URLs in `KnownPackages.registry`). `AddableFeature.snapKit` / `.lookin` cases deleted; the `PackageSpec.snapKit` / `.lookin` statics in `AddFeatureHandlers` deleted. `monolith add lottie` is unaffected (Lottie also writes a helper file, so it stays in the `AddableFeature` flow).
- **`ColorDeriver.DerivedPalette.photoBrowserBackground`** — every derived value was identical (`#1A1A1A` light + dark), making the dynamic-color wrapper pointless. LumiKit 0.9.0's `LMKTheme` protocol ships a default `photoBrowserBackground` (`UIColor(white: 0.1, alpha: 1)`); generated themes omit the override entirely. Apps wanting a different always-dark variant override the property directly.
- **`DesignSystem.MacWindow`** — see Changed; the canonical home is `AppConstants.MacWindow`.

## [0.3.0] - 2026-05-24

### Added
- **`--use-packages` flag on `new app` and `new package`** — built-in registry of well-known third-party packages. `--use-packages 'SnapKit,Lottie:5.0.0,LookinServer'` wires the dep without URL typing. Optional `:version` per identifier overrides the registry default; unknown identifiers raise a config-time error with a "did you mean…?" suggestion. Adding a new well-known package is now a registry entry, not a generator change.
- **`--external-packages` + `--target-deps` on `new app`** — ports the package generator's flags to the app generator so apps can wire arbitrary SPM frameworks (any third-party library) outside the built-in registry. URL form: `'Name=url:requirement[:packageName];...'` (requirement is verbatim SPM: `from: "0.1.0"`, `branch: "main"`, `exact: "1.0.0"`). Path form: `'Name=path[:packageName]'` (no requirement; for local-package development where the adopting project sits alongside the library). `--target-deps 'Product1,Product2,...'` wires products into the app target. Routing: direct name match → longest-prefix match (`PrismCore` → `Prism`) → single-external fallback → explicit `:packageName` disambiguation. Externals override built-ins: `--external-packages 'LumiKit=path:../LumiKit'` replaces the default GitHub URL with a local path.
- **`--executable-targets` on `new package`** — emits ArgumentParser-wired `@main` Swift executables alongside the library targets, with `swift run tool1` instructions in the generated README. Auto-adds `swift-argument-parser` as a transitive dep.
- **`--test-helper-targets` on `new package`** — declares test-helper library targets (typically a `<Name>Testing` sibling consumed by adopter test targets). Generates a Swift Testing stub (`import Testing`, public expectations namespace) instead of a plain library placeholder; XCTest interop is opt-in (`import XCTest` links it on demand). Rejects `@MainActor`-named helpers — Swift Testing's `await` semantics fight MainActor isolation on shared helpers.
- **Config-time validation for package wiring** — `AppConfig.validate()` and `PackageConfig.validate()` reject unconsumed `--external-packages` (declared but never referenced from `--target-deps`), bare-product typos (e.g. `--target-deps LumiKit` against a package whose products are `LumiKitCore` / `LumiKitUI` — previously matched by package-name fallback, generated bad XcodeGen YAML, and failed at `xcodebuild`), and target-name collisions with the app target.
- **Path-traversal guard in `FileWriter`** — rejects relative output paths containing `..` segments that resolve outside the project root.

### Changed
- **`snapKit` and `lookin` removed from `AppFeature`** — replaced by the `KnownPackages` registry (consumed via `--use-packages`). `--features snapKit,lookin` still works for one minor version via a deprecation shim that auto-translates and emits a stderr warning. Removed entirely in v0.4. Principle: `--features` is for code-shaping integrations (LumiKit's theme + `LMKNavigationController` + LMKLogger; Lottie's `LottieHelper.swift` template); the registry is for "just wire the dep" cases.
- **Generated packages are lint-clean and build clean on first run** — platform-floor merged across targets, imports sorted, `// TODO:` placeholders dropped, internal-lib imports auto-added to source stubs, external deps imported in placeholders, organization-name case preserved, `make build` / `make test` preferred over raw `xcodebuild` snippets, Brewfile pins centralized.
- **App scaffolds are App Store-ready out of the box** — `INFOPLIST_KEY_LSApplicationCategoryType` baked into Debug + Release (silent upload rejection otherwise), automatic code signing enabled, shared Xcode scheme generated, `validate-app-icon.sh` wired into the Makefile when `appIconValidation` is on, YAGNI coordinator stubs pruned.
- **Widget `PrivacyInfo.xcprivacy` is now unconditional** — every shipped widget bundle gets its own manifest with baseline values (`NSPrivacyTracking=false`, empty arrays). App Store privacy-report generation concatenates per-bundle manifests; missing files produce "Missing API usage description" feedback at upload. Was previously gated behind the `privacyManifest` feature.
- **`MakefileGenerator` gains `disableTestParallelism`** — auto-on for any app that selects Core Data / SwiftData. Emits `-parallel-testing-enabled NO` on the test target to match the documented `*.shared` singleton race seen in Petfolio.
- **SnapKit wires transitively through LumiKit** — when LumiKit is selected, the SnapKit dep is no longer duplicated at the app level (LumiKit re-exports SnapKit's public surface).
- **`swift package resolve` branches by project system** — runs for `xcodeProj` / SPM packages (where the resolved file is committed); skipped for `xcodeGen` (XcodeGen owns resolution).
- **`strictConcurrency` is a no-op at `swift-tools-version: 6.2`** — dropped from the `full` preset and from `XcodeGenGenerator`'s emitted settings; strict concurrency is the language default. Flag still accepted for backwards-compat with a stderr warning.

### Tests
- 717 → 774 tests, 68 → 70 suites, zero regressions. New coverage spans the `--use-packages` / `--external-packages` / `--target-deps` flag matrix (registry lookup, version override, unknown identifier, platform conditional emit, deprecation shim, unconsumed externals, bare-product typos, multi-product routing, local-path emit), package sibling targets (executables, test helpers), App Store hygiene (widget `PrivacyInfo`, `disableTestParallelism`), `FileWriter` path-traversal guard, transitive SnapKit-via-LumiKit detection, and project-system-branched `swift package resolve`.

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

[0.3.0]: https://github.com/Luminoid/Monolith/releases/tag/0.3.0
[0.2.0]: https://github.com/Luminoid/Monolith/releases/tag/0.2.0
[0.1.0]: https://github.com/Luminoid/Monolith/releases/tag/0.1.0
