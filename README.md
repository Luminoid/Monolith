<p align="center">
  <img src="Resources/icon.png" alt="Monolith" width="128" height="128">
</p>

# Monolith

A Swift CLI that scaffolds **iOS apps**, **Swift Packages**, and **Swift CLIs** with Swift 6.2 strict concurrency, design-system tokens, App Store hygiene (privacy manifests, app-icon alpha checks), and a tested 22-color theme derivation pipeline — production-grade defaults out of the box, no hand-wiring `project.yml` for tabs, widgets, CloudKit, or Mac Catalyst.

## Who scaffolded with Monolith

These conventions are battle-tested through real ships, not aspirational templates:

- **Apps on the App Store**: [Plantfolio Plus](https://apps.apple.com/us/app/plantfolio-plus/id6757148663) (plant care, watering, collections) and [Petfolio](https://apps.apple.com/us/app/petfolio-pet-care/id6764127493) (pet care, health, food, vet, Family Sharing, 20 app icons, 3 locales).
- **Swift Packages**: [LumiKit](https://swiftpackageindex.com/Luminoid/LumiKit) (design tokens, themeable UIKit components, theming pipeline) and [Prism](https://swiftpackageindex.com/Luminoid/Prism) (AVFoundation camera pipeline with actor-isolated session, manual exposure / Live Photo / Portrait / burst / night, Metal-backed filter chain).

Every gotcha those projects hit on the way to shipping is encoded as a generator default here, so you don't relearn it from a 2 AM crash report.

---

## Table of Contents

1. [Who scaffolded with Monolith](#who-scaffolded-with-monolith)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [Usage](#usage)
6. [Shared Flags](#shared-flags)
7. [Presets](#presets)
8. [App Features (27)](#app-features-27)
9. [Package Features](#package-features)
10. [CLI Features](#cli-features)
11. [License Types](#license-types)
12. [Architecture](#architecture)
13. [Build & Test](#build--test)
14. [Dependencies](#dependencies)
15. [TODO](#todo)
16. [License](#license)
17. [Changelog](#changelog)

---

## Requirements

- Swift 6.2+
- macOS 14+

---

## Installation

```bash
git clone https://github.com/Luminoid/Monolith.git
cd Monolith
swift build -c release
cp .build/release/monolith /usr/local/bin/
```

---

## Quick Start

```bash
# Interactive wizard — guided prompts with step progress, back navigation, and confirmation
monolith new app

# Non-interactive — all options via flags (great for CI/scripting)
monolith new app --name MyApp --preset standard --no-interactive

# Save config for reuse
monolith new app --name MyApp --preset standard --save-config myapp.json --no-interactive
monolith new app --load-config myapp.json
```

---

## Usage

Every command supports **interactive** (full-page wizard with step progress, back navigation, and confirmation) and **non-interactive** (all options via flags) modes.

Git author name is read from `git config user.name` for LICENSE and README generation.

### Create an iOS App

```bash
monolith new app \
  --name MyApp \
  --bundle-id com.company.myapp \
  --deployment-target 18.0 \
  --platforms iPhone,iPad \
  --project-system xcodeproj \
  --primary-color "#4CAF7D" \
  --features swiftData,darkMode,combine,devTooling \
  --tabs "Home:house.fill,Settings:gear" \
  --git \
  --no-interactive
```

| Option | Default | Description |
|--------|---------|-------------|
| `--name` | *(required)* | App name (letter start, alphanumeric/hyphens/underscores, max 50 chars) |
| `--bundle-id` | `com.example.<name>` | Bundle identifier in reverse-DNS format |
| `--deployment-target` | `18.0` | Minimum iOS version (`major.minor`, >= 18.0) |
| `--platforms` | `iPhone` | Comma-separated: `iPhone`, `iPad`, `macCatalyst` |
| `--project-system` | `xcodeproj` | `xcodeproj` (default) or `xcodegen` |
| `--primary-color` | `#007AFF` | Hex color (`#RRGGBB`) — derives a 22-color theme palette |
| `--features` | *(none)* | Comma-separated feature flags (see [App Features](#app-features-27)) |
| `--tabs` | *(none)* | Tab definitions as `Name:sf.symbol` pairs, comma-separated |
| `--license` | `proprietary` | License type: `mit`, `apache2`, `proprietary` (see [License Types](#license-types)) |
| `--git` / `--no-git` | *(prompted)* | Initialize git repository with initial commit |

Plus all [shared flags](#shared-flags).

**Auto-derived features:** `tabs` auto-enables when `--tabs` is provided. `macCatalyst` auto-enables when `--platforms` includes `macCatalyst`. `darkMode` auto-enables when `lumiKit` is selected.

<details>
<summary>Generated app structure</summary>

```
MyApp/
  Package.swift                           # or project.yml (XcodeGen)
  ExportOptions.plist
  MyApp/
    Info.plist
    App/
      AppDelegate.swift
      SceneDelegate.swift
      MainTabBarController.swift          # if --tabs
    Core/
      AppConstants.swift
      Models/SampleItem.swift             # if swiftData
      Services/DataPublisher.swift        # if combine
      Services/AsyncService.swift         # if combine
      L10n.swift                          # if localization
    Features/
      Home/HomeViewController.swift       # one per tab
      Settings/SettingsViewController.swift
    Shared/
      Design/DesignSystem.swift
      Design/MyAppTheme.swift             # if lumiKit (or AppTheme.swift if darkMode)
      Components/LottieHelper.swift       # if lottie
    MacCatalyst/MacWindowConfig.swift     # if macCatalyst
    Resources/
      Assets.xcassets/
      Localizable.xcstrings               # if localization
  MyAppTests/
    MyAppTests.swift
    Helpers/TestContext.swift              # if swiftData
    Helpers/TestDataFactory.swift          # if swiftData
  .gitignore
  README.md
  .swiftlint.yml                          # if devTooling
  .swiftformat                            # if devTooling
  Makefile                                # if devTooling
  Brewfile                                # if devTooling
  Scripts/git-hooks/pre-commit            # if gitHooks
  .claude/CLAUDE.md                       # if claudeMD
  LICENSE                                 # if licenseChangelog
  CHANGELOG.md                            # if licenseChangelog
  fastlane/Appfile                        # if fastlane
  fastlane/Fastfile                       # if fastlane
  Gemfile                                 # if fastlane
  Mintfile                                # if rSwift
```

</details>

### Create a Swift Package

```bash
monolith new package \
  --name MyLib \
  --targets Core,UI \
  --target-deps "UI:Core" \
  --platforms "iOS 18.0,macOS 15.0" \
  --features devTooling \
  --main-actor-targets UI \
  --git \
  --no-interactive
```

| Option | Default | Description |
|--------|---------|-------------|
| `--name` | *(required)* | Package name |
| `--targets` | `<name>` | Comma-separated target names |
| `--target-deps` | *(none)* | Dependencies: `"TargetB:TargetA;TargetC:TargetA,Other"` (semicolon-separated entries, colon separates target from its deps) |
| `--package-deps` | *(none)* | Cross-cutting deps auto-merged into every target's dependencies (comma-separated). Resolved like `--target-deps`. |
| `--test-helper-targets` | *(none)* | Test-helper library targets, comma-separated. Generates a Swift Testing stub (`import Testing`) instead of the plain library placeholder, and skips the auto `Tests/<name>Tests/` fixture. For `*Testing` siblings consumed by adopter test targets (e.g. `MultiLibTesting`). XCTest interop is opt-in (add `import XCTest`; `swift test` links it on demand). |
| `--target-resources` | *(none)* | Per-target resource directories: `"Target:dir1,dir2;Target2:Resources"`. Emits `resources: [.process(...)]` on each listed target. |
| `--external-packages` | *(none)* | External SPM packages: `"Name=url:requirement[:package];..."`. `requirement` is verbatim SPM (`from: "0.1.0"`, `branch: "main"`, etc.). Overrides the built-in registry. **Must be consumed** by some target's `--target-deps` or `--package-deps`, otherwise validation fails (unreferenced entries would be silently dropped from the emitted `Package.swift`). |
| `--platforms` | `iOS 18.0` | Comma-separated: `"iOS 18.0,macOS 15.0"` |
| `--features` | *(none)* | Comma-separated feature flags (see [Package Features](#package-features)) |
| `--main-actor-targets` | *(none)* | Targets with `defaultIsolation: MainActor` (requires `defaultIsolation` feature) |
| `--license` | `mit` | License type: `mit`, `apache2`, `proprietary` (see [License Types](#license-types)) |
| `--git` / `--no-git` | *(prompted)* | Initialize git repository |

Plus all [shared flags](#shared-flags).

**Multi-target framework example** (five-product package with a shared LumiKit dep, debug-only resources, and a Swift Testing helper library — the kind of layout used for an SDK whose adopters need a `*Testing` sibling target to write tests against):

```bash
monolith new package \
  --name MultiLib \
  --targets MultiLib,MultiLibAdapters,MultiLibDebug,MultiLibTesting,MultiLibReporting \
  --target-deps "MultiLibAdapters:MultiLib;MultiLibDebug:MultiLib;MultiLibTesting:MultiLib;MultiLibReporting:MultiLib" \
  --platforms "iOS 18.0" \
  --features defaultIsolation,devTooling,gitHooks,claudeMD,licenseChangelog \
  --main-actor-targets MultiLib,MultiLibAdapters,MultiLibDebug \
  --package-deps LumiKitUI \
  --test-helper-targets MultiLibTesting \
  --target-resources "MultiLibDebug:Resources" \
  --license mit \
  --git \
  --no-interactive
```

<details>
<summary>Generated package structure</summary>

```
MyLib/
  Package.swift
  Sources/
    Core/Core.swift
    UI/UI.swift
  Tests/
    CoreTests/CoreTests.swift
    UITests/UITests.swift
  .gitignore
  README.md
  .swiftlint.yml                          # if devTooling
  .swiftformat                            # if devTooling
  Makefile                                # if devTooling
  Brewfile                                # if devTooling
  Scripts/git-hooks/pre-commit            # if gitHooks
  .claude/CLAUDE.md                       # if claudeMD
  LICENSE                                 # if licenseChangelog
  CHANGELOG.md                            # if licenseChangelog
```

</details>

### Create a Swift CLI

```bash
monolith new cli \
  --name mytool \
  --features argumentParser,devTooling,claudeMD \
  --git \
  --no-interactive
```

| Option | Default | Description |
|--------|---------|-------------|
| `--name` | *(required)* | CLI name |
| `--features` | *(none)* | Comma-separated feature flags (see [CLI Features](#cli-features)) |
| `--license` | `apache2` | License type: `mit`, `apache2`, `proprietary` (see [License Types](#license-types)) |
| `--git` / `--no-git` | *(prompted)* | Initialize git repository |

Plus all [shared flags](#shared-flags).

<details>
<summary>Generated CLI structure</summary>

```
mytool/
  Package.swift
  Sources/
    mytool/mytool.swift
  Tests/
    mytoolTests/mytoolTests.swift
  .gitignore
  README.md
  .swiftlint.yml                          # if devTooling
  .swiftformat                            # if devTooling
  Makefile                                # if devTooling
  Brewfile                                # if devTooling
  Scripts/git-hooks/pre-commit            # if gitHooks
  .claude/CLAUDE.md                       # if claudeMD
  LICENSE                                 # if licenseChangelog
  CHANGELOG.md                            # if licenseChangelog
```

</details>

### Other Commands

```bash
# List features (all or filtered by type)
monolith list features
monolith list features --type app

# Add feature to existing project
monolith add devTooling
monolith add claudeMD --path ~/Projects/MyApp
monolith add gitHooks --dry-run

# Check tool availability
monolith doctor

# Shell completions
monolith completions zsh > ~/.zfunc/_monolith

# Version
monolith version
```

Additive features for `add`: `devTooling`, `gitHooks`, `claudeMD`, `licenseChangelog`.

`doctor` checks: `swift` (required), `git`, `swiftlint`, `swiftformat`, `xcodegen`, `mint`, `fastlane`.

---

## Shared Flags

These flags are available on all `new` commands (`new app`, `new package`, `new cli`):

| Flag | Default | Description |
|------|---------|-------------|
| `--preset` | *(none)* | `minimal`, `standard`, or `full` — pre-selects features |
| `--force` | `false` | Overwrite existing project directory without prompting |
| `--open` | `false` | Open project in Xcode after generation |
| `--resolve` | `false` | Run `swift package resolve` after generation (SPM only) |
| `--save-config` | *(none)* | Save configuration to JSON file for reuse |
| `--load-config` | *(none)* | Load configuration from JSON file |
| `--output` | current directory | Output directory for generated project |
| `--dry-run` | `false` | Preview generated files without writing |
| `--no-interactive` | `false` | Skip prompts (`--name` becomes required) |

---

## Presets

| Preset | Features |
|--------|----------|
| `minimal` | No features |
| `standard` | devTooling, gitHooks, claudeMD |
| `full` | All features (SPM apps exclude rSwift, fastlane) |

---

## App Features (27)

### Data
| Feature | Flag | Description |
|---------|------|-------------|
| SwiftData | `swiftData` | Sample @Model, ModelContainer setup, test helpers |
| Core Data | `coreData` | NSManagedObject scaffold + persistent container with fatalError on load failure |
| CloudKit | `cloudKit` | NSPersistentCloudKitContainer wiring + `registerForRemoteNotifications()` |
| CloudKit Sharing | `cloudKitSharing` | CKShare acceptance hooks in SceneDelegate |

### UI / third-party
| Feature | Flag | Description |
|---------|------|-------------|
| LumiKit | `lumiKit` | LumiKit dependency with 22-color theme generation from primary color |
| SnapKit | `snapKit` | SnapKit dependency for programmatic Auto Layout |
| Lottie | `lottie` | Lottie animation dependency, optional LumiKitLottie integration |
| LookinServer | `lookin` | LookinServer UI debugging (iOS only, debug builds) |
| Dark Mode | `darkMode` | Standalone AppTheme with adaptive UIColor patterns (auto-derived from LumiKit) |
| Combine | `combine` | Publisher/subscriber boilerplate, async Task patterns |

### System
| Feature | Flag | Description |
|---------|------|-------------|
| Notifications | `notifications` | UNUserNotificationCenter wiring + permission request |
| Deep Links | `deepLinks` | URL scheme handler with route dispatch |
| Spotlight | `spotlight` | CSSearchable item handler + continueUserActivity |
| Deferred Launch | `deferredLaunchWork` | Post-activation work scheduler (off the launch critical path) |
| Widget | `widget` | WidgetKit extension target + App Group entitlements |
| Localization | `localization` | String Catalog + L10n helper + `make audit-strings` audit script |

### App Store hygiene
| Feature | Flag | Description |
|---------|------|-------------|
| Privacy Manifest | `privacyManifest` | PrivacyInfo.xcprivacy on app + extension targets (App Store requirement) |
| App Icon Validation | `appIconValidation` | Build-phase script flagging icons with alpha channel before submission |

### Tooling
| Feature | Flag | Description |
|---------|------|-------------|
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| Core Data Audit Hook | `coreDataAuditHook` | Pre-commit reminder when `.xcdatamodel` changes (auto-enabled with `coreData` + `cloudKit` + `gitHooks`) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | License file (configurable type) and Keep a Changelog template |

### Legacy (XcodeGen only)
| Feature | Flag | Description |
|---------|------|-------------|
| R.swift | `rSwift` | R.swift code generation + Mintfile (inactive development — Xcode 15+ has native type-safe resources) |
| Fastlane | `fastlane` | Gemfile, Appfile, Fastfile (prefer Makefile or Xcode Cloud) |

### Auto-derived
| Feature | Flag | Description |
|---------|------|-------------|
| Tabs | auto | Tab bar controller — auto-enabled when `--tabs` is provided |
| Mac Catalyst | auto | Window config, menu bar — auto-enabled when `--platforms` includes `macCatalyst` |

---

## Package Features

| Feature | Flag | Description |
|---------|------|-------------|
| Strict Concurrency | `strictConcurrency` | **No-op at swift-tools-version 6.2** (strict concurrency is the language default). Flag accepted for backwards-compat; generates no `swiftSettings` entry. |
| Default Isolation | `defaultIsolation` | `defaultIsolation: MainActor` on selected targets |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | License file (configurable type) and Keep a Changelog template |

---

## CLI Features

| Feature | Flag | Description |
|---------|------|-------------|
| ArgumentParser | `argumentParser` | Swift ArgumentParser dependency |
| Strict Concurrency | `strictConcurrency` | **No-op at swift-tools-version 6.2** (strict concurrency is the language default). Flag accepted for backwards-compat; generates no `swiftSettings` entry. |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | License file (configurable type) and Keep a Changelog template |

---

## License Types

The `--license` flag controls which license is generated when `licenseChangelog` is enabled. Each project type has a different default:

| Type | `--license` value | Default for | Description |
|------|-------------------|-------------|-------------|
| MIT | `mit` | Package | Permissive, minimal restrictions. Most common for Swift packages |
| Apache 2.0 | `apache2` | CLI | Permissive with patent grant. Standard for developer tooling |
| Proprietary | `proprietary` | App | All rights reserved. Standard for commercial iOS apps |

```bash
# Override default
monolith new app --name MyApp --license mit --features licenseChangelog --no-interactive
monolith new package --name MyLib --license apache2 --features licenseChangelog --no-interactive

# Add license to existing project (auto-detects project type for default)
monolith add licenseChangelog --license mit
```

---

## Architecture

All source code lives in a `MonolithLib` library target. A thin `monolith` executable calls `Monolith.main()`. This enables `@testable import MonolithLib` in tests.

```
Monolith/
  Package.swift
  Sources/
    CEditLine/                    # System library module for macOS editline (arrow key support)
    MonolithLib/
      Monolith.swift              # @main ParsableCommand
      Commands/                   # New{App,Package,CLI}, List, Add, Doctor, Completions, Version
      Config/                     # AppConfig, PackageConfig, CLIConfig, Feature, Preset, ConfigFile, AddableFeature, DependencyVersion
      Prompts/                    # PromptEngine (readline), WizardEngine, WizardStep, Validators
      Generators/
        App/                      # 26 generators
        Package/                  # 3 generators
        CLI/                      # 3 generators
        Shared/                   # 10 generators (SwiftLint, SwiftFormat, Makefile, etc.)
      Utilities/                  # FileWriter, ShellRunner, SignalHandler, UISymbols,
                                  # ColorDeriver, ToolChecker, OverwriteProtection,
                                  # ProjectDetector, ProjectOpener, ProjectYamlEditor,
                                  # XcodeGenRunner, PackageResolver
    monolith/
      main.swift
  Tests/MonolithTests/            # 631 tests, 68 suites
```

**80 source files**, **631 tests** (Swift Testing), all passing.

### Key Patterns

- **Pure function generators** — each generator is `(Config) -> String` with no side effects
- **Feature flags drive generation** — `resolvedFeatures` auto-derives tabs, macCatalyst, darkMode
- **ColorDeriver** — HSB manipulation from 1 hex color to 22 LMKTheme colors
- **Synchronous ParsableCommand** — no async; all readline, FileManager, string ops

---

## Build & Test

```bash
swift build              # Build
swift test               # Run all 631 tests
swift run monolith version   # Smoke test
```

---

## Integration Test Coverage

Integration tests live in three suites under `Tests/MonolithTests/`, all nested under `MonolithIntegrationSuite` (an `@Suite(.serialized) enum`) so `.serialized` propagates downward. Required because every integration test mutates `currentDirectoryPath` via `withTempDir`, and Swift Testing's `.serialized` is per-suite, not global.

| File | Purpose |
|------|---------|
| `IntegrationTests.swift` | Baseline smoke tests (one per project type), negative tests (feature deliberately OFF), output-dir flag, ecosystem color sanity. |
| `AppFeatureIntegrationTests.swift` | One test per `AppFeature` in isolation + the recommended-everything-on combo + isolated combination tests. |
| `PackageCLIIntegrationTests.swift` | Per-`PackageFeature` and per-`CLIFeature` coverage + license variants. |

Every option appears in **exactly one** focused test (plus the everything-on combo for interaction stability). Combinations with output distinct from the sum of parts get their own dedicated test.

### App features → test that covers it

| Option | Test |
|--------|------|
| `swiftData` | `App with all features generates expected files` (also exercised in `App with every recommended option enabled stays self-consistent`) |
| `coreData` | `Core Data without CloudKit emits NSPersistentContainer stack and non-CloudKit model` |
| `cloudKit` | `CloudKit auto-derives Core Data and registers for remote notifications` |
| `cloudKitSharing` | `CloudKit Sharing implies CloudKit and emits CKSharingSupported plus accept handler` |
| `coreDataAuditHook` (auto-derived) | `coreDataAuditHook is auto-derived when persistence + cloudKit + gitHooks coexist` |
| `lumiKit` (auto-derives `darkMode`) | `LumiKit auto-enables darkMode and emits theme file plus LMK wiring` |
| `snapKit` | `SnapKit is wired into project.yml dependencies` |
| `lottie` | `Lottie emits helper and wires SPM dependency` |
| `lookin` | `Lookin is gated to iOS-only platforms in project.yml` |
| `darkMode` (standalone, no LumiKit) | `App with all features generates expected files` baseline (emits `AppTheme.swift`); per-color theme correctness in `all ecosystem primary colors generate valid themes` |
| `combine` | `App with all features generates expected files` baseline |
| `notifications` | `notifications wires UNUserNotificationCenterDelegate and import` |
| `deepLinks` | `deepLinks emit URL scheme and SceneDelegate handlers` |
| `spotlight` | `spotlight emits NSUserActivity handler in SceneDelegate` |
| `deferredLaunchWork` | `deferredLaunchWork emits helper in SceneDelegate` |
| `widget` | `widget extension emits target files, App Group, and entitlements` |
| `privacyManifest` | `privacyManifest writes PrivacyInfo file even without widget` |
| `appIconValidation` | `appIconValidation writes executable build-phase script` |
| `localization` | `App with all features generates expected files` baseline (also `SPM app project writes Package_swift…`) |
| `tabs` (auto-derived from non-empty tabs array) | `App with all features generates expected files` baseline |
| `macCatalyst` (auto-derived from platform) | `App with all features generates expected files` baseline (also `Lookin…` test) |
| `devTooling` | `CLI project generates all expected files` + baseline `App with all features` |
| `gitHooks` | `Pre-commit hook has executable permissions` + baseline |
| `claudeMD` | `CLI project generates all expected files` + Package/CLI all-feature tests |
| `licenseChangelog` | `each LicenseType generates a matching LICENSE file` (covers all 3 license bodies) |
| `rSwift` | `rSwift emits Mintfile and surfaces deprecation warning` |
| `fastlane` | `fastlane emits Gemfile, Appfile, Fastfile and surfaces deprecation warning` |

### Project systems

| Option | Test |
|--------|------|
| `xcodeProj` | `App project generates core files` baseline; content check in `generated project.yml is valid for xcodeProj app` |
| `xcodeGen` | `App with all features generates expected files` baseline |
| `spm` (app) | `SPM app project writes Package_swift with iOS platform` |

### Platforms

| Option | Test |
|--------|------|
| `iPhone` | every app test |
| `iPad` | `App with every recommended option enabled stays self-consistent` |
| `macCatalyst` | baseline `App with all features` + `Lookin` + `tabs combined with macCatalyst` + everything-on combo |

### Package features

| Option | Test |
|--------|------|
| `strictConcurrency` | `Package with every PackageFeature generates expected files` + `CLI with every CLIFeature generates expected files` |
| `defaultIsolation` + `mainActorTargets` | `Package with every PackageFeature generates expected files` (only `BigLibUI` is in `mainActorTargets` — verifies per-target opt-in) |
| `devTooling` / `gitHooks` / `claudeMD` / `licenseChangelog` | `Package with every PackageFeature generates expected files` |
| `packageDeps` (cross-cutting) | `Package with packageDeps, testHelperTargets, targetResources, and externalPackages wires them in` |
| `testHelperTargets` (Swift Testing stub, no auto-test sibling) | same test |
| `targetResources` (`.process(...)`) | same test |
| `externalPackages` (registry override) | same test |
| Bare package (zero features) | `Package with no features omits tooling and docs` |

### CLI features

| Option | Test |
|--------|------|
| `argumentParser` ON | `generated CLI main has ArgumentParser structure` + `CLI with every CLIFeature generates expected files` |
| `argumentParser` OFF | `CLI without ArgumentParser omits dependency from Package_swift` |
| `strictConcurrency` / `devTooling` / `gitHooks` / `claudeMD` / `licenseChangelog` | `CLI with every CLIFeature generates expected files` |

### License types

| Option | Test |
|--------|------|
| `mit` / `apache2` / `proprietary` | `each LicenseType generates a matching LICENSE file` |

### Negative tests (asserting a feature is correctly absent when not requested)

| Behavior | Test |
|----------|------|
| Hook script present without Makefile | `Git hooks without devTooling generates hook but no Makefile` |
| Makefile present without hook script | `DevTooling without gitHooks generates no hook script` |
| Pre-commit script is `0o755` executable | `Pre-commit hook has executable permissions` |
| Bare package skips tooling and docs | `Package with no features omits tooling and docs` |
| CLI without ArgumentParser skips dep | `CLI without ArgumentParser omits dependency from Package_swift` |

### Combinations with distinct output (each gets a dedicated test)

The per-feature tests can't catch behaviors that emerge from interactions. These combinations produce output that neither feature alone would emit:

| Combination | Distinct behavior | Test |
|-------------|-------------------|------|
| `widget` + `privacyManifest` | Emits **two** `PrivacyInfo.xcprivacy` files (app bundle + widget bundle), not one. App-Store-required: every shipped bundle needs its own manifest. | `widget plus privacyManifest emits manifest in widget bundle too` |
| `tabs` + `macCatalyst` | AppDelegate's `buildMenu(with:)` block gains per-tab `⌘1`, `⌘2`, …`⌘N` `UIKeyCommand` entries inside a `UIMenu(title: "Tabs"…)`. Neither feature alone emits these. | `tabs combined with macCatalyst emit per-tab UIKeyCommand entries` |
| `coreData` + `cloudKit` + `gitHooks` | Auto-derives `coreDataAuditHook`, appending the Core Data model-change reminder to the pre-commit script. Triple-condition rule that no single feature triggers. | `coreDataAuditHook is auto-derived when persistence + cloudKit + gitHooks coexist` |
| `cloudKit` alone (no `coreData`/`swiftData`) | Auto-inserts `coreData` so CloudKit has a backing store; also flips Info.plist `UIBackgroundModes: remote-notification` and registers for remote notifications in AppDelegate. | `CloudKit auto-derives Core Data and registers for remote notifications` |
| `cloudKitSharing` alone | Auto-derives `cloudKit` → `coreData`; emits `CKSharingSupported = true` in Info.plist + `userDidAcceptCloudKitShareWith` in SceneDelegate. | `CloudKit Sharing implies CloudKit and emits CKSharingSupported plus accept handler` |
| `lumiKit` alone | Auto-derives `darkMode` but replaces standalone `AppTheme.swift` with `<App>Theme.swift` (LumiKit owns full theming). Standalone darkMode emits the inverse file. | `LumiKit auto-enables darkMode and emits theme file plus LMK wiring` |
| `widget` + `bundleID` | Derives App Group identifier `group.<bundleID>` into both the entitlements file and the shared `AppGroup.swift`. Must match between app and widget targets or `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil at runtime. | `widget extension emits target files, App Group, and entitlements` |
| `deepLinks` + `name` | Derives lowercase-name URL scheme (`<name>` lowercased) into Info.plist `CFBundleURLSchemes`. | `deepLinks emit URL scheme and SceneDelegate handlers` |
| **Every recommended option ON together** | Picks recommended tech for either/or choices (`swiftData` over `coreData`, `xcodeProj` over `xcodeGen`/`spm`, `proprietary` license per app default; legacy `rSwift`/`fastlane` excluded). Verifies generator interactions: SwiftData wins over Core Data when both *could* apply, AppDelegate imports the union of every feature's libraries without one path clobbering another, SceneDelegate carries CloudKit-sharing + deep links + spotlight + deferred-launch hooks side-by-side. | `App with every recommended option enabled stays self-consistent` |

### Adding new tests

When you add a new option to `Feature.swift` / `AppConfig.resolvedFeatures`:
1. Add **one** focused integration test in the appropriate file (per-feature suite).
2. If the new option's behavior changes when combined with an existing option, add **one** combination test under "Combinations with distinct output" and update the table above.
3. If the new option is on the recommended-everything-on path, include it in `App with every recommended option enabled stays self-consistent` and update its assertions.
4. Update this matrix in the same commit.

---

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| [ArgumentParser](https://github.com/apple/swift-argument-parser) | 1.7.0+ | Command-line argument parsing |
| CEditLine (system) | macOS built-in | Terminal line editing with arrow key support (via `libedit`) |

---

## TODO

### Infrastructure
- [ ] Set up GitHub Actions CI (test on push/PR)
- [ ] Add DocC API reference documentation
- [ ] Create CONTRIBUTING.md

### Features
- [ ] `monolith update` — update generated files in existing projects
- [ ] Plugin system for custom generators

---

## License

Monolith is released under the Apache License 2.0. See [LICENSE](LICENSE) for details.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.
