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

### Create an iOS App

```bash
# Interactive
monolith new app

# Non-interactive
monolith new app \
  --name MyApp \
  --bundle-id com.company.myapp \
  --platforms iPhone,iPad \
  --project-system spm \
  --primary-color "#4CAF7D" \
  --features swiftData,darkMode,combine,devTooling \
  --tabs "Home:house.fill,Settings:gear" \
  --git \
  --no-interactive
```

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

### Version

```bash
monolith version
```

---

## App Features (18)

| Feature | Flag | Description |
|---------|------|-------------|
| SwiftData | `swiftData` | Sample @Model, ModelContainer setup, test helpers |
| LumiKit | `lumiKit` | LumiKit dependency with theme generation from primary color |
| SnapKit | `snapKit` | SnapKit dependency for programmatic Auto Layout |
| Lottie | `lottie` | Lottie animation dependency, optional LumiKitLottie integration |
| Dark Mode | `darkMode` | Standalone AppTheme with adaptive UIColor patterns |
| Combine | `combine` | Publisher/subscriber boilerplate, async Task patterns |
| Localization | `localization` | String Catalog + L10n helper with `String(localized:)` |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| R.swift | `rSwift` | R.swift code generation (XcodeGen only) |
| Fastlane | `fastlane` | Gemfile, Appfile, Fastfile (XcodeGen only) |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | MIT license and Keep a Changelog template |
| Tabs | auto | Tab bar controller (auto-enabled from `--tabs`) |
| Mac Catalyst | auto | Window config, menu bar (auto-enabled from `--platforms macCatalyst`) |

---

## Package Features

| Feature | Flag | Description |
|---------|------|-------------|
| Strict Concurrency | `strictConcurrency` | Swift 6 strict concurrency settings |
| Default Isolation | `defaultIsolation` | `defaultIsolation: MainActor` on selected targets |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
| CLAUDE.md | `claudeMD` | Project-specific Claude Code guide |
| License + Changelog | `licenseChangelog` | MIT license and Keep a Changelog template |

---

## CLI Features

| Feature | Flag | Description |
|---------|------|-------------|
| ArgumentParser | `argumentParser` | Swift ArgumentParser dependency |
| Strict Concurrency | `strictConcurrency` | Swift 6 strict concurrency settings |
| Dev Tooling | `devTooling` | SwiftLint, SwiftFormat, Makefile, Brewfile |
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
      Config/                     # AppConfig, PackageConfig, CLIConfig, Feature enums
      Prompts/                    # PromptEngine (readline), Validators
      Generators/
        App/                      # 20 generators
        Package/                  # 3 generators
        CLI/                      # 3 generators
        Shared/                   # 7 generators (FileWriter, Gitignore, README, etc.)
      Utilities/                  # ColorDeriver
    monolith/
      main.swift
  Tests/MonolithTests/            # 132 tests, 12 suites
```

**47 source files**, **132 tests** (Swift Testing), all passing.

---

## Build & Test

```bash
swift build              # Build
swift test               # Run all 132 tests
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
