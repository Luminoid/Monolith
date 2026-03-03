# Monolith

Swift CLI tool that scaffolds **iOS apps**, **Swift Packages**, and **Swift CLIs** — encoding patterns proven across [Plantfolio](https://apps.apple.com/us/app/plantfolio-plus/id6757148663) and [LumiKit](https://github.com/Luminoid/LumiKit).

---

## Requirements

- Swift 6.2+
- macOS 14+

---

## Installation

```bash
# Build from source
git clone https://github.com/Luminoid/Monolith.git
cd Monolith
swift build -c release

# Copy to PATH
cp .build/release/monolith /usr/local/bin/
```

---

## Usage

Every command supports two modes: **interactive** (full-page wizard) and **non-interactive** (all options via flags). Run without `--no-interactive` for the wizard flow, or pass all flags for CI/scripting.

The interactive wizard shows one prompt per page with step progress (Step N of M), a summary of previous answers, back navigation (type `<` or `back`), and a confirmation page before generating.

Git author name is automatically read from `git config user.name` for LICENSE and README generation.

### Create an iOS App

```bash
# Interactive — guided prompts for every option
monolith new app

# Non-interactive — all options via flags
monolith new app \
  --name MyApp \
  --bundle-id com.company.myapp \
  --deployment-target 18.0 \
  --platforms iPhone,iPad \
  --project-system spm \
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
| `--project-system` | `spm` | `spm` or `xcodegen` |
| `--primary-color` | `#007AFF` | Hex color (`#RRGGBB`) — derives a 22-color theme palette |
| `--features` | *(none)* | Comma-separated feature flags (see [App Features](#app-features-14)) |
| `--tabs` | *(none)* | Tab definitions as `Name:sf.symbol` pairs, comma-separated |
| `--git` / `--no-git` | *(prompted)* | Initialize git repository with initial commit |
| `--output` | current directory | Output directory for generated project |
| `--dry-run` | `false` | Preview generated files without writing |
| `--no-interactive` | `false` | Skip prompts (`--name` becomes required) |

**Auto-derived features:** `tabs` auto-enables when `--tabs` is provided. `macCatalyst` auto-enables when `--platforms` includes `macCatalyst`. `darkMode` auto-enables when `lumiKit` is selected (LumiKit includes full theme support).

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
# Interactive
monolith new package

# Non-interactive
monolith new package \
  --name MyLib \
  --targets Core,UI \
  --target-deps "UI:Core" \
  --platforms "iOS 18.0,macOS 15.0" \
  --features strictConcurrency,devTooling \
  --main-actor-targets UI \
  --git \
  --no-interactive
```

| Option | Default | Description |
|--------|---------|-------------|
| `--name` | *(required)* | Package name |
| `--targets` | `<name>` | Comma-separated target names |
| `--target-deps` | *(none)* | Dependencies: `"TargetB:TargetA;TargetC:TargetA,Other"` (semicolon-separated entries, colon separates target from its deps) |
| `--platforms` | `iOS 18.0` | Comma-separated: `"iOS 18.0,macOS 15.0"` |
| `--features` | *(none)* | Comma-separated feature flags (see [Package Features](#package-features)) |
| `--main-actor-targets` | *(none)* | Targets with `defaultIsolation: MainActor` (requires `defaultIsolation` feature) |
| `--git` / `--no-git` | *(prompted)* | Initialize git repository |
| `--output` | current directory | Output directory for generated project |
| `--dry-run` | `false` | Preview generated files without writing |
| `--no-interactive` | `false` | Skip prompts (`--name` becomes required) |

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
# Interactive
monolith new cli

# Non-interactive
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
| `--git` / `--no-git` | *(prompted)* | Initialize git repository |
| `--output` | current directory | Output directory for generated project |
| `--dry-run` | `false` | Preview generated files without writing |
| `--no-interactive` | `false` | Skip prompts (`--name` becomes required) |

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

### Version

```bash
monolith version
```

---

## App Features (15)

| Feature | Flag | Description |
|---------|------|-------------|
| SwiftData | `swiftData` | Sample @Model, ModelContainer setup, test helpers |
| LumiKit | `lumiKit` | LumiKit dependency with 22-color theme generation from primary color |
| SnapKit | `snapKit` | SnapKit dependency for programmatic Auto Layout |
| Lottie | `lottie` | Lottie animation dependency, optional LumiKitLottie integration |
| Dark Mode | `darkMode` | Standalone AppTheme with adaptive UIColor patterns |
| Combine | `combine` | Publisher/subscriber boilerplate, async Task patterns |
| Localization | `localization` | String Catalog + L10n helper with `String(localized:)` |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| R.swift | `rSwift` | R.swift code generation (XcodeGen only) |
| Fastlane | `fastlane` | Gemfile, Appfile, Fastfile (XcodeGen only) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | MIT license and Keep a Changelog template |
| Tabs | auto | Tab bar controller — auto-enabled when `--tabs` is provided |
| Mac Catalyst | auto | Window config, menu bar — auto-enabled when `--platforms` includes `macCatalyst` |

---

## Package Features

| Feature | Flag | Description |
|---------|------|-------------|
| Strict Concurrency | `strictConcurrency` | Swift 6 strict concurrency settings |
| Default Isolation | `defaultIsolation` | `defaultIsolation: MainActor` on selected targets |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | MIT license and Keep a Changelog template |

---

## CLI Features

| Feature | Flag | Description |
|---------|------|-------------|
| ArgumentParser | `argumentParser` | Swift ArgumentParser dependency |
| Strict Concurrency | `strictConcurrency` | Swift 6 strict concurrency settings |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| Git Hooks | `gitHooks` | Pre-commit hook (lint + format check on staged files) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | MIT license and Keep a Changelog template |

---

## Architecture

All source code lives in a `MonolithLib` library target. A thin `monolith` executable calls `Monolith.main()`. This enables `@testable import MonolithLib` in tests.

```
Monolith/
  Package.swift
  Sources/
    MonolithLib/
      Monolith.swift              # @main ParsableCommand
      Commands/                   # NewCommand, NewApp/Package/CLI, Version
      Config/                     # AppConfig, PackageConfig, CLIConfig, Feature, DependencyVersion
      Prompts/                    # PromptEngine, WizardEngine, WizardStep, Validators
      Generators/
        App/                      # 21 generators
        Package/                  # 3 generators
        CLI/                      # 3 generators
        Shared/                   # 10 generators (SwiftLint, SwiftFormat, Makefile, etc.)
      Utilities/                  # FileWriter, ColorDeriver, ColorCodeGenerator, StringExtensions
    monolith/
      main.swift
  Tests/MonolithTests/            # 294 tests, 38 suites
```

**57 source files**, **294 tests** (Swift Testing), all passing.

---

## Build & Test

```bash
swift build              # Build
swift test               # Run all 294 tests
swift run monolith version   # Smoke test
```

---

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| [ArgumentParser](https://github.com/apple/swift-argument-parser) | 1.7.0+ | Command-line argument parsing |

---

## License

Monolith is released under the MIT License. See [LICENSE](LICENSE) for details.
