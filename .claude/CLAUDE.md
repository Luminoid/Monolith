# Monolith — Claude Code Guide

> Swift CLI that scaffolds iOS apps, Swift Packages, and Swift CLIs. Pure Swift, no UIKit, no simulator needed for tests.

## Project Overview

Monolith is a Swift CLI tool that scaffolds iOS apps, Swift Packages, and Swift CLIs. It encodes patterns proven across Plantfolio and LumiKit.

**Version**: 0.4.0 (released)
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
      Commands/               # NewCommand (router) + New{App,Package,CLI}, NewCommandRunner
                              # (shared post-config orchestration), AddCommand, AddFeatureHandlers,
                              # List, Doctor, Completions, Version, ValidationErrorBridge
      Config/                 # AppConfig, PackageConfig, CLIConfig, Feature, Preset, ConfigFile, AddableFeature, DependencyVersion
      Prompts/                # PromptEngine (readline), WizardEngine, WizardStep, Validators
      Generators/
        App/                  # 27 generators (AppDelegate, SceneDelegate, TabBar, Theme,
                              # LocalizationAudit, ColorCodeGenerator, etc.)
        Package/              # 3 generators
        CLI/                  # 3 generators
        Shared/               # 10 generators (SwiftLint, SwiftFormat, Makefile, etc.)
      Utilities/              # FileWriter, ShellRunner, SignalHandler, UISymbols,
                              # ColorDeriver, StringExtensions, ToolChecker, OverwriteProtection,
                              # ProjectDetector, ProjectOpener, ProjectYamlEditor,
                              # XcodeGenRunner, PackageResolver
    monolith/                 # Thin executable
      main.swift
  Tests/MonolithTests/        # 794 tests, 71 suites — mirrors source structure
```

### Key Patterns

- **Pure function generators**: Each generator is `(Config) -> String` with no side effects
- **Synchronous ParsableCommand**: No async — all readline, FileManager, string ops
- **Feature flags drive generation**: `AppConfig.resolvedFeatures` auto-derives tabs, macCatalyst, darkMode
- **ColorDeriver**: HSB manipulation from 1 hex to 22 LMKTheme colors
- **Shell-out centralized**: All `Process()` calls route through `ShellRunner` (`run` / `runDiscardingOutput` / `runCapturingStdout`). Surfaces `error.localizedDescription` and stderr on failure instead of silently returning `false` like the pre-refactor `XcodeGenRunner`/`PackageResolver`/`ProjectOpener`/`ToolChecker`/`FileWriter.gitInit` did
- **CLI output symbols** live in `UISymbols` (✓ ✗ ⚠ ↻ ─ ↑). Never hard-code `"\u{2713}"` inline
- **Ctrl-C cleanup**: `SignalHandler.install(cleanup:)` is invoked by each `new` command after `OverwriteProtection.check` clears, so an interrupt mid-generation removes the partial output directory. The wizard's raw-mode `0x03` path now `raise(SIGINT)`s instead of `exit(0)`-ing so the same handler runs there too

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
- `--test-helper-targets` (comma-separated): test-helper library targets — typically a `<Name>Testing` sibling (e.g. `MultiLibTesting`) consumed by adopter test targets. Generates a Swift Testing stub source file (`import Testing`, public expectations namespace) instead of the plain library placeholder, and skips the auto-generated `Tests/<name>Tests/` fixture (these libraries exist to be consumed, not tested in isolation). No `linkerSettings` — Swift Testing is bundled with the toolchain; XCTest interop is opt-in (add `import XCTest` to the source, `swift test` links it on demand).
- `--target-resources` (`"Target:dir1,dir2;..."`): emits `resources: [.process(...)]` per target.

### Package wiring on `new app` AND `new package` (v0.3.0+)

Three flags cover the spectrum from "registered well-known package" → "arbitrary SPM repo with version" → "local-path development":

- **`--use-packages`** (`"Name[:version],Name[:version],..."`): built-in registry of well-known packages, **`new app` only**. Currently registered: `SnapKit`, `Lottie`, `LookinServer`. Bare identifier uses the registry's default version; optional `:version` overrides per call. Synthesizes `ExternalPackage` entries from `KnownPackages.registry` (in `Config/DependencyVersion.swift`). Adding a new well-known package is a registry entry, not a generator change. Unknown identifier → config-time error with a "did you mean…?" message. `new package` adopters wire registry packages explicitly via `--external-packages` (the registry is internal-only on the package surface today — see `Sources/MonolithLib/Commands/NewPackageCommand.swift`).
- **`--external-packages`** (`"Name=url:requirement[:packageName];..."` URL form, or `"Name=path[:packageName]"` path form): declares SPM packages outside the registry. `requirement` for URL form is verbatim SPM (`from: "0.1.0"`, `branch: "main"`, `exact: "1.0.0"`, etc.). Path form has no requirement segment (paths are unversioned). Externals override built-ins: `--external-packages 'LumiKit=path:../LumiKit'` replaces Monolith's default GitHub URL with a local path. The parser lives on `ExternalPackage.parse(_:)` / `parseUsePackages(_:)` in `Config/Feature.swift` so all commands share one parser surface.
- **`--target-deps`** on `new app` (comma-separated `Product1,Product2,...`): products to link into the main app target. Resolution is four-tier — direct match against an external's `name`, then longest-prefix match (`PrismCore` resolves to `Prism` for multi-product packages), then single-external fallback, then `product=package` fallback. De-dupes against built-in feature wirings. Platform conditionals come from `KnownPackages.registry` when present (LookinServer is iOS-only → emits `condition: .when(platforms: [.iOS])` in `Package.swift`, `platforms: [iOS]` in XcodeGen YAML).
- **Must be consumed**: every `--external-packages` entry must be referenced by `--target-deps`. Single-external + non-empty target-deps passes (multi-product case); multi-external requires each external by name. Two errors: `externalPackageCollidesWithTarget` and `externalPackageNotConsumed`.

### App Features (26)

Data: `swiftData`, `coreData`, `cloudKit`, `cloudKitSharing`
UI / third-party: `lumiKit`, `lottie`, `darkMode`, `combine`
System: `notifications`, `deepLinks`, `spotlight`, `deferredLaunchWork`, `widget`, `localization`
App Store hygiene: `privacyManifest`, `appIconValidation`
Tooling: `devTooling`, `gitHooks`, `coreDataAuditHook`, `claudeMD`, `licenseChangelog`
Legacy (XcodeGen only): `rSwift`, `fastlane`
No-op for cross-target symmetry: `strictConcurrency` (accepted on `new app` so adopters who also pass it on `new package` / `new cli` aren't surprised; warns on stderr at swift-tools-version 6.2 where strict concurrency is already the language default)
Auto-derived: `tabs` (from non-empty tabs array), `macCatalyst` (from platform), `darkMode` (from lumiKit), `coreDataAuditHook` (from coreData/swiftData + cloudKit + gitHooks)

**Moved to the `--use-packages` registry**: `snapKit` → `--use-packages SnapKit`, `lookin` → `--use-packages LookinServer`. Promoted to the `KnownPackages` registry in v0.3.0; the auto-translating shim ran for one minor version and was removed in v0.4. The CLI now raises a `ValidationError` listing the migration when these tokens show up in `--features`. The principle: `--features` is for code-shaping integrations (LumiKit's theme + LMKNavigationController + LMKLogger; Lottie's `LottieHelper.swift` template); the registry is for "just wire the dep" cases.

Not recommended: `rSwift` (XcodeGen only, inactive development — Xcode 15+ has native type-safe resources), `fastlane` (XcodeGen only, prefer Makefile or Xcode Cloud)

### `monolith add <feature>` — retrofit features into an existing project

Two tiers, both invoked as `monolith add <feature> [--path <dir>] [--dry-run]`:

- **Tier 1 — pure file writes (any project system)**: `devTooling`, `gitHooks`, `claudeMD`, `licenseChangelog`, `privacyManifest`, `appIconValidation`
- **Tier 2 — app projects only**: `localization`, `macCatalyst`, `lottie`, `widget`. On XcodeGen projects, the command edits `project.yml` in place (idempotent — re-running is a no-op); re-run `xcodegen generate` afterward. On `.xcodeproj` projects, the source files are written but the user must perform manual integration steps (target membership, Add Package, entitlements) which the command prints.

(Removed in v0.4: `snapKit`, `lookin`. Retrofit those via Xcode → File → Add Package Dependencies… against the URLs in `KnownPackages.registry`.)

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
- Integration test coverage matrix (which option is verified by which test, plus combinations with distinct output) lives in [README.md](../README.md#integration-test-coverage)
- **Generic placeholder names in tests**, never internal project names. Use `MultiLib` / `MultiLibCore` / `MultiLibUI` / `MultiLibTesting` etc. for multi-target framework fixtures, and `ExtPkg` for an arbitrary external SPM package. Avoid Causeway / Prism / Plantfolio / Petfolio — those are workspace-internal and shouldn't leak into Monolith (a general-purpose tool).

### Substring-only assertions are not enough

`yml.contains("string")` and `pkg.contains("...")` style assertions can pass against output that's syntactically broken or semantically wrong. Two historical examples (May 2026): xcodegen YAML emitted `preBuildScripts:` at column 0 instead of nested under the target — every `devTooling` app's `project.yml` was unparseable, yet the substring assertion passed. Similarly, `- package: LumiKit` matched `yml.contains("LumiKit")` but LumiKit has no product named `LumiKit` (the actual products are `LumiKitCore` / `LumiKitUI` / `LumiKitLottie` / `LumiKitNetwork`), so xcodebuild failed with "Missing package product".

When a new feature's output has structural meaning (YAML indentation, init chains, import lines, package products), add a **structural** assertion alongside the substring one. Parse the YAML, regex over indentation, check the exact line sequence — whatever proves the output is actually well-formed, not just contains a known token.

### Build-the-output verification

Substring tests don't run xcodegen or xcodebuild against the generated project, so compile-time errors in the templates (Sendable conformance, init inheritance, missing imports) only surface when an adopter scaffolds and tries to build. When changing any generator that emits Swift code or `project.yml`, regenerate at least one affected fixture and run `xcodegen generate && xcodebuild -quiet build -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`. The 50 integration-test configurations defined across `Tests/MonolithTests/IntegrationTests.swift`, `AppFeatureIntegrationTests.swift`, and `PackageCLIIntegrationTests.swift` make a convenient corpus, regenerate any subset into a scratch dir (e.g. `/tmp/monolith-test-projects/`) and build them.

## SwiftLint & SwiftFormat

Run `make check` to verify both. Pre-commit hook (`Scripts/git-hooks/pre-commit`) runs them automatically.

Generated projects inherit the same SwiftLint / SwiftFormat config as Monolith itself (see `.swiftlint.yml`, `.swiftformat`). Notable settings:
- Swift 6.2, `--trailing-commas collections-only`, `--self remove`, `--indent 4`
- Force unwrapping and force casting are warnings (not allowed in any committed code)
- Trailing commas mandatory on collection literals
- `@Test` method names should NOT be prefixed with `test`

---

*Optimized for Claude Code.*
