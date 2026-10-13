<p align="center">
  <img src="Resources/icon.png" alt="Monolith" width="128" height="128">
</p>

# Monolith

[![Release](https://img.shields.io/github/v/release/Luminoid/Monolith)](https://github.com/Luminoid/Monolith/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/macOS-14%2B-blue.svg)](#requirements)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)

A Swift CLI that scaffolds **iOS apps**, **Swift Packages**, and **Swift CLIs**. Generates Swift 6.2 strict concurrency, design-system tokens, privacy manifests, app-icon alpha checks, and a light/dark theme derived from one hex color that meets WCAG AA contrast. No hand-wiring `project.yml` for tabs, widgets, CloudKit, or Mac Catalyst.

## Who scaffolded with Monolith

- **Apps on the App Store**: [Petfolio](https://apps.apple.com/us/app/petfolio-pet-care/id6764127493) (pet care, health, food, vet, Family Sharing, 20 app icons, 3 locales), [TripDays](https://apps.apple.com/us/app/tripdays-trip-planner/id6794614173) (collaborative travel planner: day-by-day itineraries, maps, shared trips over iCloud, expense splitting), and [Metamer](https://apps.apple.com/us/app/metamer/id6779320695) (color-vision camera: live CVD simulation, daltonize filters, color naming, Ishihara plate generator, built on Prism).
- **Swift Packages**: [Prism](https://swiftpackageindex.com/Luminoid/Prism) (AVFoundation camera pipeline with actor-isolated session, manual exposure / Live Photo / Portrait / burst / night, Metal-backed filter chain) and [Sophon](https://swiftpackageindex.com/Luminoid/Sophon) (LLM clients for Gemini, OpenAI-compatible APIs, and Anthropic on one core, with structured output, retry policies, and model catalogs).
- **Mac apps and CLIs**: [Tethersnap](https://github.com/Luminoid/Tethersnap) (SwiftUI app + CLI that export Nintendo Switch 2 captures over USB; notarized DMG built from the generated Makefile).

---

## Table of Contents

1. [Who scaffolded with Monolith](#who-scaffolded-with-monolith)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [Usage](#usage)
6. [Shared Flags](#shared-flags)
7. [Package Wiring](#package-wiring)
8. [Presets](#presets)
9. [App Features](#app-features)
10. [Package Features](#package-features)
11. [CLI Features](#cli-features)
12. [License Types](#license-types)
13. [Architecture](#architecture)
14. [Build & Test](#build--test)
15. [Integration Test Coverage](#integration-test-coverage)
16. [Dependencies](#dependencies)
17. [TODO](#todo)
18. [Related projects](#related-projects)
19. [License](#license)
20. [Changelog](#changelog)

---

## Requirements

- Swift 6.2+ (Xcode 26 or later)
- macOS 14+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for `new app` (`brew install xcodegen`): an `.xcodeproj` app is generated through it, and an XcodeGen app needs it to create the project. `monolith doctor` checks for it.

---

## Installation

Homebrew (from [Luminoid/homebrew-tap](https://github.com/Luminoid/homebrew-tap)):

```bash
brew install luminoid/tap/monolith
```

From source:

```bash
git clone https://github.com/Luminoid/Monolith.git
cd Monolith
swift build -c release
cp .build/release/monolith /usr/local/bin/
```

Monolith is also listed on the [Swift Package Index](https://swiftpackageindex.com/Luminoid/Monolith).

---

## Quick Start

```bash
# Interactive wizard with step progress, back navigation, and confirmation (needs a terminal)
monolith new app

# Non-interactive: all options via flags (great for CI/scripting)
monolith new app --name MyApp --preset standard --no-interactive

# Save config for reuse
monolith new app --name MyApp --preset standard --save-config myapp.json --no-interactive
monolith new app --load-config myapp.json
```

---

## Usage

Every `new` command supports **interactive** (full-page wizard with step progress, back navigation, and confirmation) and **non-interactive** (all options via flags) modes. Flags passed to an interactive run answer their wizard steps. In the wizard, type `<` or press the up arrow to go back. The wizard needs a terminal; in scripts and CI, pass `--no-interactive`.

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
  --use-packages SnapKit,Lottie \
  --tabs "Home:house.fill,Settings:gear" \
  --git \
  --no-interactive
```

| Option | Default | Description |
|--------|---------|-------------|
| `--name` | *(required)* | App name: a Swift identifier (an ASCII letter, then letters, digits, or underscores; max 50 chars), since it becomes type and module names |
| `--bundle-id` | `com.example.<name>` | Bundle identifier in reverse-DNS format (ASCII) |
| `--deployment-target` | `18.0` | Minimum iOS version (`major.minor`, >= 18.0) |
| `--platforms` | `iPhone,iPad` | Comma-separated: `iPhone`, `iPad`, `macCatalyst`. Sets the device family: `--platforms iPhone` makes an iPhone-only app |
| `--project-system` | `xcodeproj` | `xcodeproj` (default) or `xcodegen` |
| `--primary-color` | `#007AFF` | Hex color (`#RRGGBB`); derives the theme's light/dark palette |
| `--features` | *(none)* | Comma-separated feature flags (see [App Features](#app-features)) |
| `--use-packages` | *(none)* | Built-in packages, linked into the app target: `"SnapKit,Lottie,LookinServer:1.2.8"` (see [Package Wiring](#package-wiring)) |
| `--external-packages` | *(none)* | Any SPM package: `"Name=url:requirement[:package];..."` or `"Name=path[:package]"` (see [Package Wiring](#package-wiring)) |
| `--target-deps` | *(none)* | Products to link into the app target, comma-separated (e.g., `ExtPkgCore,ExtPkgUI`) |
| `--tabs` | *(none)* | Tab definitions as `Name:sf.symbol` pairs, comma-separated |
| `--locales` | `en` | Locales for `Localizable.xcstrings`, comma-separated; the first is the source language (used with `localization`) |
| `--category` | `public.app-category.utilities` | App Store category (`LSApplicationCategoryType`) |
| `--license` | `proprietary` | License type: `mit`, `apache2`, `proprietary` (see [License Types](#license-types)) |
| `--git` / `--no-git` | off (the wizard asks) | Initialize a git repository with an initial commit |

Plus all [shared flags](#shared-flags).

**Auto-derived features:** `tabs` auto-enables when `--tabs` is provided. `macCatalyst` auto-enables when `--platforms` includes `macCatalyst`. `darkMode` auto-enables when `lumiKit` is selected. `cloudKitSharing` implies `cloudKit`, and `cloudKit` without `swiftData` adds `coreData`. `coreDataAuditHook` auto-enables when `coreData` or `swiftData` is combined with `cloudKit` and `gitHooks`. Passing `tabs`, `macCatalyst`, or `coreDataAuditHook` in `--features` is an error that names the input driving it.

**One persistence layer:** `swiftData` can't be combined with `coreData`, or with `cloudKitSharing` (sharing needs Core Data's shared store).

<details>
<summary>Generated app structure</summary>

```
MyApp/
  MyApp.xcodeproj                         # or project.yml (--project-system xcodegen)
  MyApp/
    Info.plist
    MyApp.entitlements                    # if cloudKit or widget
    MyApp-MacCatalyst.entitlements        # if macCatalyst (App Sandbox + network + the iOS capabilities)
    App/
      AppDelegate.swift
      SceneDelegate.swift
      MainTabBarController.swift          # if --tabs
    Core/
      AppConstants.swift
      Models/SampleItem.swift             # if swiftData (AppSchema.models + a sample @Model)
      Models/MyApp.xcdatamodeld/          # if coreData
      Models/.gitkeep                     # if neither
      Persistence/MyAppCoreDataStack.swift  # if coreData
      Services/AsyncService.swift         # if combine
      L10n.swift                          # if localization
    Features/                             # placeholder .gitkeep if no --tabs
      Home/HomeViewController.swift       # one per tab
      Settings/SettingsViewController.swift
    Shared/
      ViewController.swift                # if no --tabs
      Design/DesignSystem.swift
      Design/MyAppTheme.swift             # if lumiKit (or AppTheme.swift if darkMode)
      Components/LottieHelper.swift       # if lottie
      AppGroup.swift                      # if widget
    MacCatalyst/MacWindowConfig.swift     # if macCatalyst without lumiKit (LumiKit apps call LMKScene)
    Resources/
      Assets.xcassets/
      Localizable.xcstrings               # if localization
      PrivacyInfo.xcprivacy               # if privacyManifest
  MyAppWidget/                            # if widget
    Info.plist
    MyAppWidget.entitlements
    MyAppWidgetBundle.swift
    MyAppWidget.swift
    PrivacyInfo.xcprivacy                 # always (every shipped bundle needs one)
  MyAppTests/
    MyAppTests.swift
    Helpers/TestContext.swift             # if swiftData or coreData
    Helpers/TestDataFactory.swift         # if swiftData or coreData
  .gitignore
  README.md
  .swiftlint.yml                          # if devTooling
  .swiftformat                            # if devTooling
  Makefile                                # if devTooling
  Brewfile                                # if devTooling
  Scripts/git-hooks/pre-commit            # if gitHooks
  Scripts/localization/audit_strings.py   # if localization
  Scripts/validate-app-icon.sh            # if appIconValidation
  .claude/CLAUDE.md                       # if claudeMD
  LICENSE                                 # if licenseChangelog
  CHANGELOG.md                            # if licenseChangelog
  fastlane/Appfile                        # if fastlane
  fastlane/Fastfile                       # if fastlane
  Gemfile                                 # if fastlane
  ExportOptions.plist                     # if fastlane
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
| `--name` | *(required)* | Package name: an ASCII letter, then letters, digits, underscores, or hyphens (max 50 chars) |
| `--targets` | `<name>` | Comma-separated target names. Suffix one with `:exec` (`my-tool:exec`) for an executable sibling: it depends on swift-argument-parser, runs its `run` subcommand by default, and gets no test target |
| `--target-deps` | *(none)* | Dependencies: `"TargetB:TargetA;TargetC:TargetA,SnapKit"` (semicolon-separated entries, colon separates target from its deps). A dep is another target, a built-in product (`SnapKit`, `Lottie`, `LookinServer`, `LumiKitCore`, `LumiKitUI`, …), or an `--external-packages` name |
| `--package-deps` | *(none)* | Cross-cutting deps auto-merged into every target's dependencies (comma-separated). Resolved like `--target-deps`. |
| `--test-helper-targets` | *(none)* | Test-helper library targets, comma-separated. Generates a Swift Testing stub (`import Testing`) instead of the plain library placeholder, and skips the auto `Tests/<name>Tests/` fixture. For `*Testing` siblings consumed by adopter test targets (e.g., `MultiLibTesting`). XCTest interop is opt-in (add `import XCTest`; `swift test` links it on demand). |
| `--target-resources` | *(none)* | Per-target resource directories: `"Target:dir1,dir2;Target2:Resources"`. Emits `resources: [.process(...)]` on each listed target. |
| `--external-packages` | *(none)* | SPM packages outside the built-in registry, or a built-in one at another version or a local path (URL or path form); each must be consumed by some target's `--target-deps` or `--package-deps` |
| `--platforms` | `iOS 18.0` | Comma-separated: `"iOS 18.0,macOS 15.0"` |
| `--features` | *(none)* | Comma-separated feature flags (see [Package Features](#package-features)) |
| `--main-actor-targets` | *(none)* | Targets with `defaultIsolation: MainActor`. Turns on the `defaultIsolation` feature, which isolates the only library target when this flag is omitted |
| `--license` | `mit` | License type: `mit`, `apache2`, `proprietary` (see [License Types](#license-types)) |
| `--git` / `--no-git` | off (the wizard asks) | Initialize a git repository |

Plus all [shared flags](#shared-flags).

**Multi-target framework example** (five-product package with a shared LumiKit dep, debug-only resources, and a Swift Testing helper library; the kind of layout used for an SDK whose adopters need a `*Testing` sibling target to write tests against):

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
    Core/Logging/MyLibLog.swift             # logging core (see below)
    Core/Logging/MyLibLog+Categories.swift
    UI/UI.swift
  Tests/
    CoreTests/CoreTests.swift
    CoreTests/MyLibLogTests.swift
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

**Logging core.** Every generated package gets `<Prefix>Log`, a small wrapper over `os.Logger`, in one library target: the one named after the package, or else the first library target with no in-package dependencies (`Core` above). It has six levels (`debug`, `info`, `notice`, `warning`, `error`, `fault`) and a runtime `minimumLevel` (default `.info`) that never filters out errors and faults. Message text is public; pass user data (URLs, paths, payloads) as `private:` and errors as `error:`, which logs the domain and code. Write functions are `package`, so every target in the package can log and consuming apps can't; apps adjust `minimumLevel` and can set `handler` to forward entries. Add categories in `<Prefix>Log+Categories.swift`. The prefix comes from the package name, and the subsystem is a `com.example.<name>` placeholder: replace it in `<Prefix>Log.swift`. The core needs iOS 16 / macOS 13 / tvOS 16 / watchOS 9 / visionOS 1 or later, so a package declaring an older deployment target is generated without it, and a package declaring no macOS version gets macOS 13 (or a wired dependency's higher macOS floor) so `swift build` works on a Mac. The generated CLAUDE.md explains how to use it.

**Build mode.** A package whose targets use `defaultIsolation: MainActor`, or depend on a UIKit-only product (`LumiKitUI`, `LumiKitPhoto`, `LumiKitLottie`), can't build with `swift build` on a Mac, so its Makefile and docs build and test with xcodebuild on an iOS Simulator (`make build`, `make test`, `IOS_VERSION` selects the runtime). Other packages use `swift build` / `swift test`.

### Create a Swift CLI

```bash
monolith new cli \
  --name my-tool \
  --features devTooling,claudeMD \
  --git \
  --no-interactive
```

| Option | Default | Description |
|--------|---------|-------------|
| `--name` | *(required)* | CLI name: an ASCII letter, then letters, digits, underscores, or hyphens (max 50 chars); it is the binary's name |
| `--features` | *(none)* | Comma-separated feature flags (see [CLI Features](#cli-features)) |
| `--no-argument-parser` | `false` | Build a plain executable without swift-argument-parser (on by default) |
| `--license` | `apache2` | License type: `mit`, `apache2`, `proprietary` (see [License Types](#license-types)) |
| `--git` / `--no-git` | off (the wizard asks) | Initialize a git repository |

Plus all [shared flags](#shared-flags).

The command lives in a library, `<Name>Kit`, so tests can import it; the executable is a thin `main.swift` that runs it. Type names are UpperCamelCased from the CLI name (`my-tool` becomes `MyToolKit`).

<details>
<summary>Generated CLI structure</summary>

```
my-tool/
  Package.swift
  Sources/
    MyToolKit/MyTool.swift                # the command
    my-tool/main.swift                    # thin executable
  Tests/
    MyToolKitTests/MyToolTests.swift      # smoke tests
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

# Add a feature to an existing project
monolith add devTooling
monolith add claudeMD --path ~/Projects/MyApp
monolith add localization --locales en,zh-Hans
monolith add widget --dry-run

# Check tool availability
monolith doctor

# Shell completions
monolith completions zsh > ~/.zfunc/_monolith

# Version
monolith version
```

**`add` retrofit features (10 total)**, split into two tiers:

- **Tier 1 (file writes, any project system)**: `devTooling`, `gitHooks`, `claudeMD`, `licenseChangelog`, `privacyManifest`, `appIconValidation`
- **Tier 2 (app projects only)**: `localization`, `macCatalyst`, `lottie`, `widget`

`add` reads the project first (its type, name, bundle ID, platforms, and features) and writes what `monolith new` would write for the same project: `add devTooling` on a Core Data app runs its tests serially, and `add gitHooks` on a CloudKit app includes the model reminder.

- **Existing files are kept**; pass `--force` to replace them. Entitlements are merged, never replaced: `add widget` adds the App Group to the app's existing entitlements, and `add macCatalyst` writes `<App>-MacCatalyst.entitlements` with the app's iOS entitlements plus App Sandbox and outgoing network access.
- **`--dry-run`** lists, file by file, whether `add` would write, keep, overwrite, or merge, and the `project.yml` edit or manual steps, without changing anything.
- **A failed `add` writes nothing**: the `project.yml` edit and the entitlement merges are worked out first, and files are written only when both succeed.
- **`--path`** names the project directory (default: the current one). The app's name comes from the project, not the folder.

On XcodeGen projects, Tier 2 edits `project.yml` in place (idempotent; re-running is a no-op); re-run `xcodegen generate` afterward. On `.xcodeproj` projects, the files are written and the command prints the manual integration steps (target membership, Add Package, entitlements, build settings). `widget` builds the extension under the app's bundle ID read from the project (`<id>.Widget`, App Group `group.<id>`); `--bundle-id` applies only when the project sets none. On a Mac Catalyst app the widget is embedded in iOS builds only. `macCatalyst` also sets an App Category and adds iPad to the device family when they are missing. `localization` takes `--locales` (default `en`), and `licenseChangelog` takes `--license`.

The other app features (`swiftData`, `coreData`, `cloudKit`, `cloudKitSharing`, `lumiKit`, `darkMode`, `combine`, `notifications`, `deepLinks`, `spotlight`, `deferredLaunchWork`, `tabs`, `rSwift`, `fastlane`, and the derived `coreDataAuditHook`), and the package feature `defaultIsolation`, require editing existing `AppDelegate.swift` / entitlements / Info.plist / `Package.swift` in ways that depend on user-modified content. Best path: re-scaffold with the new feature set into a temp dir and cherry-pick the diff.

`doctor` checks `swift` (required), `git`, `xcodegen` (required for `new app`), `swiftlint`, `swiftformat`, `mint`, and `fastlane`, and says what each is for. It exits non-zero only when `swift` is missing; a missing `xcodegen` is reported as a warning.

---

## Shared Flags

These flags are available on all `new` commands (`new app`, `new package`, `new cli`):

| Flag | Default | Description |
|------|---------|-------------|
| `--preset` | *(none)* | `minimal`, `standard`, or `full`; its features are added to `--features` (see [Presets](#presets)) |
| `--force` | `false` | Overwrite existing project directory without prompting |
| `--open` | `false` | Open project in Xcode after generation |
| `--resolve` | `false` | Resolve package dependencies after generation: `swift package resolve` (packages, CLIs) or `xcodebuild -resolvePackageDependencies` (apps) |
| `--save-config` | *(none)* | Save the resolved configuration to a JSON file for reuse (skipped with `--dry-run`) |
| `--load-config` | *(none)* | Load the whole configuration from a JSON file: no wizard, and no options that set the config (`--name`, `--features`, `--preset`, …) |
| `--output` | current directory | Output directory for generated project |
| `--dry-run` | `false` | Preview generated files without writing |
| `--no-interactive` | `false` | Skip prompts (`--name` becomes required) |
| `--verbose` | `false` | Stream the output of xcodegen, git, package resolution, and `open` as they run |

`--git` and `--no-git` can't be passed together. Without the wizard, git stays off unless `--git` is given.

Saved config files record a schema version and the Monolith version that wrote them. `--load-config` runs the same checks as flags, rejects a file saved for another project type or by a newer schema, and warns about keys it doesn't know.

A `SIGINT` (Ctrl-C) or a failure mid-generation removes the partial output directory if the directory didn't exist before the run; an interrupted run stops at the next file and exits with status 130. Pre-existing directories under `--force` are left in place to avoid blowing away unrelated content. The one exception is an `.xcodeproj` app whose xcodegen step fails: every other file is written, so the output stays (with `project.yml`) and the error says how to finish.

Failures exit non-zero, including a non-interactive run refusing a non-empty directory without `--force` and a declined overwrite prompt. Progress goes to stdout; warnings and errors go to stderr.

---

## Package Wiring

`new app` has three flags for third-party packages: **`--use-packages`** for the built-in registry, **`--external-packages`** for any SPM package (a URL with a version, or a local path), and **`--target-deps`** to link products into the app target. `new package` has no `--use-packages`: built-in products resolve by name in its `--target-deps` / `--package-deps`, and anything else is declared with `--external-packages`.

### `--use-packages` (built-in registry, `new app` only)

Currently registered: `SnapKit`, `Lottie`, `LookinServer`. Bare identifier uses the registry's default version; optional `:version` overrides per call. Each entry is linked into the app target, so it doesn't need repeating in `--target-deps`.

```bash
monolith new app --name MyApp --use-packages 'SnapKit,Lottie,LookinServer:1.2.8'
```

An unknown identifier produces a config-time error with a "did you mean…?" message. LumiKit and ArgumentParser are rejected with a pointer to the flag that wires them (`--features lumiKit`, or `--external-packages` for a LumiKit checkout). Adding a new well-known package is a registry entry (`Config/KnownPackages.swift`), not a generator change. Platform conditionals come from the registry: LookinServer is iOS-only, so it emits `platforms: [iOS]` in XcodeGen YAML and `condition: .when(platforms: [.iOS])` in a package's `Package.swift`.

### `--external-packages` (any SPM package)

URL form: `"Name=url:requirement[:packageName];..."` where the URL has a scheme (`https://…`) or is an scp-style git remote (`git@github.com:owner/repo.git`), and `requirement` is verbatim SPM (`from: "0.1.0"`, `branch: "main"`, `exact: "1.0.0"`, etc.).

Path form: `"Name=path[:packageName]"`; no requirement segment (paths are unversioned).

```bash
# URL form
monolith new app --name MyApp \
  --external-packages 'ExtPkg=https://github.com/example/ExtPkg.git:from: "1.0.0"' \
  --target-deps ExtPkgCore,ExtPkgUI

# Local-path form for parallel development (`Name=path`, no `://`, no requirement)
monolith new app --name MyApp \
  --external-packages 'LumiKit=../LumiKit' \
  --target-deps LumiKitUI
```

Externals override built-ins: `--external-packages 'LumiKit=../LumiKit'` replaces Monolith's default GitHub URL with the local path. Path-form entries emit `.package(name:path:)`; absolute paths are normalized to project-root-relative so the manifest stays portable.

**On `new package`**, built-in products (`SnapKit`, `Lottie`, `LookinServer`, `LumiKitCore`, `LumiKitUI`, `LumiKitPhoto`, `LumiKitDebug`, `LumiKitLottie`) need no declaration: name them in `--target-deps` or `--package-deps` and the registry's URL and version are used. Declare a package with `--external-packages` to use anything else, or a built-in one at another version or from a local path. The must-be-consumed check matches an external's `Name` against the names in `--target-deps` / `--package-deps`, and those name *products*, not packages. So for a multi-product package, wire one entry per product you consume, using the `:packageName` tail to point them at the same SPM package. Duplicate declarations de-dupe into a single `.package(...)` line:

```bash
monolith new package --name MyLib \
  --targets MyLibCore,MyLibUI \
  --target-deps "MyLibCore:LumiKitCore;MyLibUI:MyLibCore,LumiKitUI" \
  --external-packages 'LumiKitCore=../LumiKit:LumiKit;LumiKitUI=../LumiKit:LumiKit'
```

### `--target-deps`

For `new app`, this is the product list to link into the main app target (comma-separated). Each product resolves to a package, in order: an external whose `name` matches it, then the external with the longest matching prefix (`ExtPkgCore` resolves to `ExtPkg`), then a built-in product whose package a feature adds (the LumiKit products with `lumiKit`, `Lottie` with `lottie`), then the only external when there is exactly one. De-dupes against built-in feature wirings.

For `new package`, the format is `"Target:Dep1,Dep2;Target2:Dep1"` (per-target).

**Validation** happens at config time, before anything is written:

- On `new app`, a product that resolves to nothing fails: a misspelling or a bare package name (`LumiKit`) gets a "did you mean", and a built-in product whose package nothing adds names the flag that would. Every `--external-packages` entry must be linked by some product (or, for a LumiKit or Lottie override, by its feature); an unlinked one would be declared in the project with no target using it.
- On `new package`, every `--external-packages` entry must be named in some target's `--target-deps` or in `--package-deps`; unreferenced entries would be silently dropped from the emitted `Package.swift`. A dep that looks like a misspelled target or built-in product fails with the likely name.

---

## Presets

A preset's features are added to whatever `--features` selects.

| Preset | App features | Package and CLI features |
|--------|--------------|--------------------------|
| `minimal` | None | None |
| `standard` | devTooling, gitHooks, claudeMD, privacyManifest | devTooling, gitHooks, claudeMD |
| `full` | Every feature the wizard offers except `swiftData` and the legacy `rSwift` / `fastlane`. An app has one persistence layer, and `full` uses Core Data, which CloudKit sharing needs | Every feature except the no-op `strictConcurrency`. On a package, `defaultIsolation` isolates the only library target unless `--main-actor-targets` says otherwise |

---

## App Features

### Data
| Feature | Flag | Description |
|---------|------|-------------|
| SwiftData | `swiftData` | Sample `@Model` and `AppSchema.models` (the one model list the app's and the test container read), `ModelContainer` setup, in-memory test helpers |
| Core Data | `coreData` | `.xcdatamodeld` model, `<App>CoreDataStack` with a persistent container (`fatalError` only when even a local store fails), test helpers |
| CloudKit | `cloudKit` | CloudKit sync for Core Data or SwiftData (adds `coreData` when neither is selected): iCloud entitlements, opt-in sync (off until the user turns it on, never in test runs), a local-store fallback, remote notifications while sync is on |
| CloudKit Sharing | `cloudKitSharing` | Core Data only: private and shared stores, `CKSharingSupported`, share acceptance on warm and cold launch |

### UI / third-party (code-shaping)
| Feature | Flag | Description |
|---------|------|-------------|
| LumiKit | `lumiKit` | LumiKit 1.x dependency: a theme derived from the primary color as an `LMKTheme` value, `LMKNavigationController` / `LMKTabBarController` navigation (a sidebar in regular-width iPad and Mac windows), `LMKScene` Mac window setup, `LMKLogger` failure logging |
| Lottie | `lottie` | Lottie dependency and a `LottieHelper` view factory (plays loops once under Reduce Motion, pauses in the background) |
| Dark Mode | `darkMode` | Standalone `AppTheme` with adaptive light/dark colors derived from the primary color, using LumiKit's role names (auto-derived from LumiKit) |
| Combine | `combine` | `AsyncService` template for Task cancellation (emits no Combine code) |

For SnapKit and LookinServer, use `--use-packages` (see [Package Wiring](#package-wiring)). They're no longer code-shaping features (they only added a dep), so they live in the registry instead.

The theme meets WCAG AA for text in both appearances: every derived accent reaches 4.5:1 against its `onAccent` color and against each background.

### System
| Feature | Flag | Description |
|---------|------|-------------|
| Notifications | `notifications` | `UNUserNotificationCenter` wiring + permission request; a tap that launches the app is held until the UI is up |
| Deep Links | `deepLinks` | URL scheme handler with route dispatch |
| Spotlight | `spotlight` | `CSSearchableItem` handler + `continueUserActivity`; a result that launches the app is held until the UI is up |
| Deferred Launch | `deferredLaunchWork` | Post-activation work, once per launch, off the launch critical path |
| Widget | `widget` | WidgetKit extension target + App Group entitlements; widget bundle always includes its own `PrivacyInfo.xcprivacy`; embedded in iOS builds only on Mac Catalyst apps |
| Localization | `localization` | String Catalog + `L10n` helper (default values and translator comments) + `make audit-strings` audit script (catches the silent-fail `\(...)` interpolation bug) |

### App Store hygiene
| Feature | Flag | Description |
|---------|------|-------------|
| Privacy Manifest | `privacyManifest` | `PrivacyInfo.xcprivacy` on app target, declaring the reasons the generated code needs (UserDefaults for CloudKit and LumiKit apps, file timestamps for LumiKit apps), with commented snippets for the rest (widget extension always gets its own regardless of this flag) |
| App Icon Validation | `appIconValidation` | `Scripts/validate-app-icon.sh`, run by `make check` and `make archive`: fails when a 1024x1024 icon has an alpha channel or a `tRNS` chunk, which App Store Connect rejects |

### Tooling
| Feature | Flag | Description |
|---------|------|-------------|
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| Core Data Audit Hook | `coreDataAuditHook` | Pre-commit reminder to check the CloudKit schema when the data model changes (`.xcdatamodel` for Core Data, `@Model` files for SwiftData); auto-enabled with `coreData`/`swiftData` + `cloudKit` + `gitHooks` |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide (CloudKit apps get a schema-safety checklist) |
| License + Changelog | `licenseChangelog` | License file (configurable type) and Keep a Changelog template |

### Legacy (XcodeGen only)
| Feature | Flag | Description |
|---------|------|-------------|
| R.swift | `rSwift` | R.swift code generation + Mintfile (inactive development; Xcode 15+ has native type-safe resources) |
| Fastlane | `fastlane` | Gemfile, Appfile, Fastfile, `ExportOptions.plist` (prefer Makefile or Xcode Cloud) |

### Auto-derived
| Feature | Flag | Description |
|---------|------|-------------|
| Tabs | auto | Tab bar controller, a View menu (⌘1…⌘9 per tab, ⌘R Refresh), selected-tab restoration; auto-enabled when `--tabs` is provided |
| Mac Catalyst | auto | Window setup (minimum size, no maximum), sandboxed Mac entitlements, `make build-catalyst` / `archive-mac` / `release-mac`; auto-enabled when `--platforms` includes `macCatalyst` |

### No-op
| Feature | Flag | Description |
|---------|------|-------------|
| Strict Concurrency | `strictConcurrency` | Accepted for symmetry with `new package` and `new cli`. Strict concurrency is the Swift 6.2 language default, so it generates nothing and prints a warning. |

### Migrated to `--use-packages` (v0.3.0+)
| Old flag | Replacement |
|----------|-------------|
| `--features snapKit` | `--use-packages SnapKit` |
| `--features lookin` | `--use-packages LookinServer` |

Both moved to the `KnownPackages` registry in v0.3.0. The auto-translating shim was removed in v0.4; the CLI now raises an error listing the migration if these tokens show up in `--features`. The principle: `--features` is for code-shaping integrations (LumiKit's theme + `LMKNavigationController` + LMKLogger; Lottie's `LottieHelper.swift` template); the registry is for "just wire the dep" cases.

---

## Package Features

| Feature | Flag | Description |
|---------|------|-------------|
| Strict Concurrency | `strictConcurrency` | **No-op at swift-tools-version 6.2** (strict concurrency is the language default). Flag accepted for backwards-compat; generates no `swiftSettings` entry. |
| Default Isolation | `defaultIsolation` | `defaultIsolation: MainActor` on the `--main-actor-targets` (the only library target when that flag is omitted); builds and tests through xcodebuild |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | License file (configurable type) and Keep a Changelog template |

---

## CLI Features

| Feature | Flag | Description |
|---------|------|-------------|
| ArgumentParser | `argumentParser` | Swift ArgumentParser dependency; on by default, off with `--no-argument-parser` |
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
    CEditLine/                    # System library module for macOS editline (yes/no prompts)
    MonolithLib/
      Monolith.swift              # @main ParsableCommand
      Commands/                   # NewCommand (router) + New{App,Package,CLI}Command,
                                  # NewCommandOptions (shared flags), NewCommandWizard,
                                  # NewCommandRunner (shared post-config orchestration),
                                  # AddCommand, AddFeatureHandlers + AddPlan (add <feature>),
                                  # List, Doctor, Completions, Version,
                                  # ArgumentValues, LocaleList, ValidationBridge
      Config/                     # AppConfig, PackageConfig, CLIConfig, ConfigValidation,
                                  # Feature, Preset, ConfigFile, AddableFeature,
                                  # ExternalPackage, KnownPackages (registry), DependencyVersion
      Prompts/                    # PromptEngine, LineEditor (raw-mode line editing),
                                  # WizardEngine, WizardStep, Validators
      Generators/
        App/                      # One generator per app output (AppDelegate, SceneDelegate,
                                  # TabBar, Theme, ColorCode, Entitlements, XcodeGen, ...)
        Package/                  # Package.swift, sources, project assembly
        CLI/                      # Package.swift, main + library, project assembly, ArgumentParserStub
        Shared/                   # SwiftLint, SwiftFormat, Makefile, Brewfile, git hooks, LogCore,
                                  # README, CLAUDE.md, ProjectDocs (text both docs share), ...
      Utilities/                  # FileWriter (path-traversal guarded), DryRunPlanner, GitRunner,
                                  # ShellRunner, SignalHandler, Console, UISymbols, ColorDeriver,
                                  # EntitlementsMerger, ProjectDetector, ProjectState,
                                  # ProjectYamlEditor, OverwriteProtection, ProjectOpener,
                                  # StringExtensions, ToolChecker, XcodeGenRunner, PackageResolver
    monolith/
      main.swift
  Tests/MonolithTests/            # Swift Testing; mirrors source structure
```

### Key Patterns

- **Pure function generators**: each generator is `(Config) -> String` with no side effects
- **Feature flags drive generation**: `resolvedFeatures` auto-derives `tabs`, `macCatalyst`, `darkMode`, `cloudKit` (from `cloudKitSharing`), `coreData` (from `cloudKit` without `swiftData`), and `coreDataAuditHook`
- **One validation path**: every config, whether from flags, the wizard, or `--load-config`, passes `validateForGeneration()` before anything is saved, previewed, or written
- **`NewCommandRunner`**: shared post-config orchestration (validate → warnings → dry-run or save-config → overwrite-check → generate with Ctrl-C armed → git init → resolve → open → next steps). The three `new` commands diverge only in config-building.
- **`DryRunPlanner`**: the `--dry-run` file list for each project type, kept in step with the generators by tests that diff it against a real run
- **`AddPlan`**: `monolith add` works out every write, entitlement merge, and `project.yml` edit before touching the disk; `--dry-run` prints the plan and a real run carries it out, so the preview can't drift from the writes
- **`KnownPackages` registry**: data-driven catalog of well-known third-party packages. Adding one is a registry entry, not a generator change.
- **`ColorDeriver`**: derives eight light/dark color roles from one hex color (three accents, `onAccent`, three backgrounds, a divider), searching brightness and saturation until every accent meets WCAG AA (4.5:1) against `onAccent` and each background. It feeds the generated `LMKColorTheme` (only the roles that differ from LumiKit's defaults) and the standalone `AppTheme`.
- **Shell-out centralized**: all `Process()` calls route through `ShellRunner`, which reads stdout and stderr while the child runs (a full pipe can't stall it), streams them under `--verbose`, and puts failures on stderr with the child's stderr (or stdout) quoted. `GitRunner` runs the initial git setup and reads the author name.
- **`SignalHandler`**: Ctrl-C during generation only sets a flag (the handler stays async-signal-safe); `FileWriter` stops before its next write, and `NewCommandRunner` removes the partial output and exits with 130. The handler is armed only while `generate` runs, so a Ctrl-C during git init, package resolve, or open leaves the finished project in place.
- **`FileWriter` path-traversal guard**: rejects absolute paths and `..` segments with a typed `FileWriterError`
- **Synchronous `ParsableCommand`**: no async; all readline, FileManager, string ops

### Build settings emitted into generated projects

- **Test serialization**: an app's tests run one at a time when it uses Core Data, or SwiftData with CloudKit (a process-wide store). One rule drives the generated test file's `.serialized` parent suite, the Makefile's `-parallel-testing-enabled NO`, and the test command in the generated docs. Plain SwiftData tests each get an in-memory container and keep the parallel run.
- **iOS app `PrivacyInfo.xcprivacy`**: always emitted for the widget bundle when `widget` is enabled (every shipped bundle needs its own per App Store), separately gated on the app-level `privacyManifest` feature for the app bundle
- **XcodeGen YAML**: `options.xcodeVersion: "26.0"`, `TARGETED_DEVICE_FAMILY` from `--platforms`, `GENERATE_INFOPLIST_FILE`, `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`; `CODE_SIGN_ENTITLEMENTS` (plus `[sdk=macosx*]` for the Mac Catalyst file); with dev tooling, `ENABLE_USER_SCRIPT_SANDBOXING: NO`, SwiftLint as `postCompileScripts`, and SwiftFormat as `preBuildScripts` with ARM64 Homebrew PATH detection

---

## Build & Test

```bash
swift build                  # Build
swift test                   # Run all tests
swift run monolith version   # Smoke test
make check                   # SwiftLint + SwiftFormat lint
```

0.5.0 shipped with 828 tests in 73 suites (Swift Testing). Some integration and lint tests need `xcodegen`, `swiftlint`, and `swiftformat` on `PATH` and are skipped without them.

---

## Integration Test Coverage

Integration tests (anything that writes a project to a temp directory, changes the working directory, or installs the Ctrl-C handler) are nested under `MonolithIntegrationSuite` (an `@Suite(.serialized) enum`) so `.serialized` propagates downward. Required because `withTempDir` mutates `currentDirectoryPath` and `new` installs a process-wide SIGINT handler, and Swift Testing's `.serialized` is per-suite, not global. The per-feature tests live in three files under `Tests/MonolithTests/`:

| File | Purpose |
|------|---------|
| `IntegrationTests.swift` | Baseline smoke tests (one per project type), negative tests (feature deliberately OFF), output-dir flag, ecosystem color sanity. |
| `AppFeatureIntegrationTests.swift` | One test per `AppFeature` in isolation + the recommended-everything-on combo + isolated combination tests. |
| `PackageCLIIntegrationTests.swift` | Per-`PackageFeature` and per-`CLIFeature` coverage, package and CLI layouts, license variants. |

Every option appears in **exactly one** focused test (plus the everything-on combo for interaction stability). Combinations with output distinct from the sum of parts get their own dedicated test. Whole-project checks (lint, dry-run parity, `add` vs. `new`) are listed [below](#whole-project-checks).

### App features → test that covers it

| Option | Test |
|--------|------|
| `swiftData` | `App with all features generates expected files` |
| `coreData` | `Core Data without CloudKit emits NSPersistentContainer stack and non-CloudKit model` (also exercised in `App with every recommended option enabled stays self-consistent`) |
| `cloudKit` | `CloudKit auto-derives Core Data and registers for remote notifications` |
| `cloudKitSharing` | `CloudKit Sharing implies CloudKit and emits CKSharingSupported plus accept handler` |
| `coreDataAuditHook` (auto-derived) | `coreDataAuditHook is auto-derived when persistence + cloudKit + gitHooks coexist` |
| `lumiKit` (auto-derives `darkMode`) | `LumiKit auto-enables darkMode and emits theme file plus LMK wiring` |
| `--use-packages SnapKit` | `SnapKit is wired into project.yml dependencies` |
| `lottie` | `Lottie emits helper and wires SPM dependency` |
| `--use-packages LookinServer` | `Lookin is gated to iOS-only platforms in project.yml` |
| `darkMode` (standalone, no LumiKit) | `App with all features generates expected files` baseline (emits `AppTheme.swift`); per-color theme correctness in `all ecosystem primary colors generate valid themes` |
| `combine` | `App with all features generates expected files` baseline |
| `notifications` | `notifications wires UNUserNotificationCenterDelegate and import` |
| `deepLinks` | `deepLinks emit URL scheme and SceneDelegate handlers` |
| `spotlight` | `spotlight emits NSUserActivity handler in SceneDelegate` |
| `deferredLaunchWork` | `deferredLaunchWork emits helper in SceneDelegate` |
| `widget` | `widget extension emits target files, App Group, and entitlements` |
| `privacyManifest` | `privacyManifest writes PrivacyInfo file even without widget` |
| `appIconValidation` | `appIconValidation writes executable build-phase script` |
| `localization` | `App with all features generates expected files` baseline |
| `tabs` (auto-derived from non-empty tabs array) | `App with all features generates expected files` baseline; View menu in `tabs combined with macCatalyst emit per-tab UIKeyCommand entries` and the everything-on combo |
| `macCatalyst` (auto-derived from platform) | `App with all features generates expected files` baseline (also Lookin test) |
| `devTooling` | `CLI project generates all expected files` + baseline `App with all features generates expected files` |
| `gitHooks` | `Pre-commit hook has executable permissions` + baseline |
| `claudeMD` | `CLI project generates all expected files` + Package/CLI all-feature tests |
| `licenseChangelog` | `each LicenseType generates a matching LICENSE file` (covers all 3 license bodies) |
| `rSwift` | `rSwift emits Mintfile and surfaces deprecation warning` |
| `fastlane` | `fastlane emits Gemfile, Appfile, Fastfile and surfaces deprecation warning` |

### Project systems

| Option | Test |
|--------|------|
| `xcodeProj` | `App project generates core files` baseline; content check in `generated project.yml is valid for xcodeProj app` |
| `xcodeGen` | `xcodeGen project keeps project_yml in place` + `App with all features generates expected files` baseline |
| `spm` (rejected for apps) | `app generator refuses SPM and writes nothing` |

### Platforms

| Option | Test |
|--------|------|
| `iPhone` | every app test |
| `iPad` | `App with every recommended option enabled stays self-consistent` |
| `macCatalyst` | baseline `App with all features generates expected files` + Lookin + `tabs combined with macCatalyst emit per-tab UIKeyCommand entries` + everything-on combo (Mac entitlements); generated-output formatting checked by `generated macCatalyst app conforms to its own swiftformat config` |

### Package features

| Option | Test |
|--------|------|
| `strictConcurrency` | `Package with every PackageFeature generates expected files` + `CLI with every CLIFeature generates expected files` |
| `defaultIsolation` + `mainActorTargets` | `Package with every PackageFeature generates expected files` (only `BigLibUI` is in `mainActorTargets`; verifies per-target opt-in) |
| `devTooling` / `gitHooks` / `claudeMD` / `licenseChangelog` | `Package with every PackageFeature generates expected files` |
| `packageDeps` (cross-cutting) | `Package with packageDeps, testHelperTargets, targetResources, and externalPackages wires them in` |
| `testHelperTargets` (Swift Testing stub, no auto-test sibling) | same test |
| `targetResources` (`.process(...)`) | same test |
| `externalPackages` (registry override) | same test |
| Executable sibling (`--targets name:exec`) | `Package with executable sibling target wires CLI scaffolding end-to-end` + `Package with MainActor lib + executable uses umbrella scheme in Makefile` |
| UIKit-only product dependency (xcodebuild build mode) | `Package wired to a UIKit-only product builds with xcodebuild even without defaultIsolation` |
| Logging core | `generated packages carry the log core and its tests` + `a package below the floor is generated without the core` + `Package CLAUDE_md documents the logging core it carries` |
| Bare package (zero features) | `Package with no features omits tooling and docs` |

### CLI features

| Option | Test |
|--------|------|
| `argumentParser` ON (default) | `generated CLI main has ArgumentParser structure` + `CLI with every CLIFeature generates expected files` |
| `argumentParser` OFF (`--no-argument-parser`) | `CLI without ArgumentParser omits dependency from Package_swift` |
| Library + thin executable layout | `hyphenated CLI generates a library, a thin executable, and library tests` |
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
| Widget alone (without `privacyManifest`) emits widget `PrivacyInfo` but no app `PrivacyInfo` | `widget extension emits target files, App Group, and entitlements` |
| Core Data apps and SwiftData + CloudKit apps emit `-parallel-testing-enabled NO`; other apps don't | `disableTestParallelism adds -parallel-testing-enabled NO to test target only` + `disableTestParallelism off by default` + `app test serialization matches its Makefile` |
| `FileWriter` rejects `..` and absolute paths | `writeFile rejects relative paths containing ..` + `writeFile rejects absolute paths in the relative arg` |

### Combinations with distinct output (each gets a dedicated test)

The per-feature tests can't catch behaviors that emerge from interactions. These combinations produce output that neither feature alone would emit:

| Combination | Distinct behavior | Test |
|-------------|-------------------|------|
| `widget` + `privacyManifest` | Emits **two** `PrivacyInfo.xcprivacy` files (app bundle + widget bundle), not one. App-Store-required: every shipped bundle needs its own manifest. | `widget plus privacyManifest emits manifest in widget bundle too` |
| `widget` alone (no `privacyManifest`) | Widget bundle still gets its own `PrivacyInfo.xcprivacy` (every shipped bundle needs one); the app bundle skips its manifest. | `widget extension emits target files, App Group, and entitlements` |
| `widget` + `macCatalyst` | The widget is embedded with `destinationFilters: [iOS]`: an iOS widget extension embedded in the Catalyst app fails the Mac build. | `widget is embedded on iOS only in a Mac Catalyst app` |
| `cloudKit` + `macCatalyst` | Both entitlements files carry the iCloud keys; the Mac file adds App Sandbox and outgoing network access and is wired through `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`. | `Mac Catalyst CloudKit app wires both entitlement files` |
| `coreData` + `cloudKit` + `gitHooks` | Auto-derives `coreDataAuditHook`, appending the Core Data model-change reminder to the pre-commit script. Triple-condition rule that no single feature triggers. (With `swiftData` in place of `coreData`, the reminder watches SwiftData models instead.) | `coreDataAuditHook is auto-derived when persistence + cloudKit + gitHooks coexist` |
| `cloudKit` alone (no `coreData`/`swiftData`) | Auto-inserts `coreData` so CloudKit has a backing store; writes the iCloud entitlements, flips Info.plist `UIBackgroundModes: remote-notification`, and registers for remote notifications while sync is on. | `CloudKit auto-derives Core Data and registers for remote notifications` |
| `cloudKitSharing` alone | Auto-derives `cloudKit` → `coreData`; emits private and shared stores behind the opt-in sync preference, `CKSharingSupported = true` in Info.plist, and `userDidAcceptCloudKitShareWith` in SceneDelegate. | `CloudKit Sharing implies CloudKit and emits CKSharingSupported plus accept handler` |
| `lumiKit` alone | Auto-derives `darkMode` but replaces standalone `AppTheme.swift` with `<App>Theme.swift` (LumiKit owns full theming). Standalone darkMode emits the inverse file. Transitive `SnapKit` wiring also derived: `LumiKitUI` already pulls SnapKit, so the generated `ViewController.swift` uses SnapKit syntax without an explicit `--use-packages SnapKit`. | `LumiKit auto-enables darkMode and emits theme file plus LMK wiring` |
| `widget` + `bundleID` | Derives App Group identifier `group.<bundleID>` into both the entitlements file and the shared `AppGroup.swift`. Must match between app and widget targets or `containerURL(forSecurityApplicationGroupIdentifier:)` returns nil at runtime. | `widget extension emits target files, App Group, and entitlements` |
| `deepLinks` + `name` | Derives lowercase-name URL scheme (`<name>` lowercased) into Info.plist `CFBundleURLSchemes`. | `deepLinks emit URL scheme and SceneDelegate handlers` |
| `coreData` (or `swiftData` + `cloudKit`) + `devTooling` | The `Makefile` `test:` target gets `-parallel-testing-enabled NO`, matching the generated test file's `.serialized` parent suite (a process-wide store races under Swift Testing's parallel scheduler). | `disableTestParallelism adds -parallel-testing-enabled NO to test target only` + `app test serialization matches its Makefile` |
| **Every recommended option ON together** | Picks one tech for each either/or choice (`coreData` over `swiftData`, since CloudKit sharing needs it; `xcodeProj` over `xcodeGen`; `proprietary` license per app default; legacy `rSwift`/`fastlane` excluded). Verifies generator interactions: the CloudKit rule doesn't add SwiftData when Core Data is selected, AppDelegate imports the union of every feature's libraries without one path clobbering another, SceneDelegate carries Core Data share acceptance (warm and cold launch) + deep links + spotlight + deferred-launch hooks side-by-side, the privacy manifest declares `CA92.1` and `C617.1`, and the Mac entitlements are sandboxed. | `App with every recommended option enabled stays self-consistent` |

### Whole-project checks

These render complete projects and check them as a whole, rather than one feature at a time:

| Suite | What it checks |
|-------|----------------|
| `GeneratedOutputLintTests` | `generated project passes its own lint and format checks`: renders a matrix of CLIs (including a hyphenated name), packages (full preset, multi-target with an executable, one depending on `LumiKitUI`), and apps (from dev tooling only to LumiKit with every other feature) with the real `new` commands, then runs `swiftlint --strict` and `swiftformat --lint` as each project's `make check` would. Skipped when either tool is missing. Also `app test serialization matches its Makefile` and `package gitignore tracks Package_resolved only with an executable`. |
| `DryRunPlannerTests` | `new app --dry-run` lists exactly the files a real run writes, for a feature-rich, a minimal, and a legacy-tooling Mac Catalyst app. |
| `CLIDryRunTests` | The same for `new cli` (`dry-run plan matches real generation`), plus `dry-run plan names the library, executable, and test files`. |
| `LogCoreGeneratorTests` | The package logging core: rendering, placement, platform floors, and `dry run lists exactly the files a real run writes`. |
| `AddCommandTests` (`add` vs. `new`) | `add devTooling writes the Makefile new writes for the same app`, `add devTooling matches new for a widget and Mac Catalyst app`, `add gitHooks includes the Core Data audit for a CloudKit model`, `add claudeMD describes the app new would describe`, `add claudeMD describes the package and CLI new would describe`, `add privacyManifest declares what new declares`, `add macCatalyst writes the Mac entitlements new writes`. `xcodegen accepts project.yml after add widget on a LumiKit CloudKit Mac Catalyst app` and `xcodegen accepts project.yml after add lottie and add macCatalyst` run xcodegen on the edited spec. |

### Adding new tests

When you add a new option to `Feature.swift` / `AppConfig.resolvedFeatures`:
1. Add **one** focused integration test in the appropriate file (per-feature suite).
2. If the new option's behavior changes when combined with an existing option, add **one** combination test under "Combinations with distinct output" and update the table above.
3. If the new option is on the recommended-everything-on path, include it in `App with every recommended option enabled stays self-consistent` and update its assertions.
4. Update this matrix in the same commit.

Substring-only assertions (`output.contains("foo")`) are not enough for structurally-meaningful output (YAML indentation, init chains, import lines, package products). Add a structural assertion alongside the substring one when the output's well-formedness matters; parse the YAML, regex over indentation, check the exact line sequence.

---

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| [ArgumentParser](https://github.com/apple/swift-argument-parser) | 1.8.2+ | Command-line argument parsing |
| CEditLine (system) | macOS built-in | Line editing for the wizard's yes/no prompts (via `libedit`) |

---

## TODO

### Infrastructure
- [ ] Set up GitHub Actions CI (test on push/PR)
- [ ] Add DocC API reference documentation

### Features
- [ ] `monolith update`: update generated files in existing projects
- [ ] Plugin system for custom generators

---

## Related projects

- [LumiKit](https://github.com/Luminoid/LumiKit): the design-token and UI-component package that the `lumiKit` feature wires in
- Everything else at [luminoid.dev](https://luminoid.dev)

---

## License

Monolith is released under the Apache License 2.0. See [LICENSE](LICENSE) for details.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.
