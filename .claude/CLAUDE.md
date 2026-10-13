# Monolith — Claude Code Guide

> Swift CLI that scaffolds iOS apps, Swift Packages, and Swift CLIs. Pure Swift, no UIKit, no simulator needed for tests.

## Project Overview

Monolith is a Swift CLI tool that scaffolds iOS apps, Swift Packages, and Swift CLIs. It encodes patterns proven across Plantfolio and LumiKit.

**Version**: 0.5.0 (released)
**Swift**: 6.2, macOS 14+
**Dependencies**: ArgumentParser 1.8.2+
**Distribution**: `brew install luminoid/tap/monolith` via [Luminoid/homebrew-tap](https://github.com/Luminoid/homebrew-tap) (source build of the release tarball); each release bumps `url` + `sha256` in the tap's `Formula/monolith.rb`. Listed on the [Swift Package Index](https://swiftpackageindex.com/Luminoid/Monolith).

## Architecture

### Library + Executable Split

All source code lives in `MonolithLib` (library target). A thin `monolith` executable just calls `Monolith.main()`. This enables `@testable import MonolithLib` in tests.

```
Monolith/
  Package.swift
  Sources/
    CEditLine/                # System library module for macOS editline (yes/no prompts)
    MonolithLib/              # All source code (testable library)
      Monolith.swift          # @main ParsableCommand
      Commands/               # NewCommand (router) + New{App,Package,CLI}Command,
                              # NewCommandOptions (shared `new` flags + --load-config rules),
                              # NewCommandWizard (terminal check, preset/closing steps),
                              # NewCommandRunner (shared post-config orchestration),
                              # AddCommand, AddFeatureHandlers (one plan per feature), AddPlan,
                              # ListCommand, DoctorCommand, CompletionsCommand, VersionCommand,
                              # ArgumentValues (ExpressibleByArgument conformances),
                              # LocaleList (--locales), ValidationBridge (typed errors → ValidationError)
      Config/                 # AppConfig, PackageConfig, CLIConfig, ConfigValidation
                              # (GeneratableConfig + validateForGeneration), Feature (feature enums,
                              # Platform, ProjectSystem, PackagePlatform, LicenseType, TabDefinition,
                              # TargetDefinition, PlatformVersion), Preset, ConfigFile, AddableFeature,
                              # ExternalPackage (--external-packages / --use-packages parsers),
                              # KnownPackages (registry), DependencyVersion (+ ToolVersion, Defaults)
      Prompts/                # PromptEngine, LineEditor (raw-mode line buffer), WizardEngine,
                              # WizardStep, Validators
      Generators/
        App/                  # One generator per app output: AppDelegate, SceneDelegate, TabBar,
                              # Theme, ColorCode, DarkMode, DesignSystem, Entitlements, InfoPlist,
                              # CoreData, SwiftData, Localization, LocalizationAudit, XcodeGen, ...
                              # AppProjectGenerator assembles them
        Package/              # PackageSwift, PackageSource, PackageProject
        CLI/                  # CLIPackageSwift, CLIMain, CLIProject, ArgumentParserStub
                              # (the CommandConfiguration block new cli and :exec targets share)
        Shared/               # SwiftLint, SwiftFormat, Makefile, Brewfile, GitHooks, Gitignore,
                              # LicenseChangelog, LogCore, Readme, ClaudeMD, Test,
                              # ProjectDocs (text README and CLAUDE.md share)
      Utilities/              # FileWriter, DryRunPlanner, GitRunner, ShellRunner, SignalHandler,
                              # Console, UISymbols, ColorDeriver, EntitlementsMerger,
                              # ProjectDetector, ProjectState, ProjectYamlEditor,
                              # OverwriteProtection, ProjectOpener, StringExtensions,
                              # ToolChecker, XcodeGenRunner, PackageResolver
    monolith/                 # Thin executable
      main.swift
  Tests/MonolithTests/        # Swift Testing; mirrors source structure (828 tests / 73 suites at 0.5.0)
```

### Key Patterns

- **Pure function generators**: Each generator is `(Config) -> String` with no side effects
- **Synchronous ParsableCommand**: No async — all readline, FileManager, string ops
- **Feature flags drive generation**: `AppConfig.resolvedFeatures` auto-derives tabs (non-empty `--tabs`), macCatalyst (platform), darkMode (lumiKit), cloudKit (cloudKitSharing), coreData (cloudKit without swiftData or coreData), coreDataAuditHook (coreData/swiftData + cloudKit + gitHooks). `--features` rejects the three that only derive (`tabs`, `macCatalyst`, `coreDataAuditHook`) with a message naming the input that drives them
- **One validation path**: `GeneratableConfig.validateForGeneration()` (Config/ConfigValidation.swift) runs in `NewCommandRunner` before anything is saved, previewed, or written, so flags, the wizard, and `--load-config` meet the same rules. Flag parsers throw typed `ConfigValidationError`s; `ValidationBridge.bridge` turns them into `ValidationError` at the command surface. Names: apps are Swift identifiers (`[A-Za-z][A-Za-z0-9_]*`), packages and CLIs may also use `-`, all ASCII, max 50 (`Validators.projectNameProblem`). One persistence layer: `swiftData` + `coreData` and `swiftData` + `cloudKitSharing` throw
- **`NewCommandRunner` pipeline**: validate → warnings → dry run (prints `DryRunPlanner`'s plan, saves no config) or `--save-config` → `OverwriteProtection.check` (a declined prompt exits 1) → `generate()` with Ctrl-C armed → git init (`GitRunner`) → resolve → open → next steps (printed last, so the hooks step shows only when git init didn't set `core.hooksPath`). The three `new` commands differ only in config building
- **`DryRunPlanner`** (Utilities/DryRunPlanner.swift): `plannedAppFiles` / `plannedPackageFiles` / CLI plan mirror their generators block by block; `DryRunPlannerTests`, `CLIDryRunTests`, and the log-core dry-run test diff each against a real generation, so a new `FileWriter.writeFile` in a generator needs a matching planner entry
- **`GitRunner`** (Utilities/GitRunner.swift): `initRepository(at:hasGitHooks:)` runs `initSteps` in order and on failure names the failed command and the ones skipped; `authorName()` / `authorNameOrPlaceholder()` read `git config user.name`
- **`monolith add` plans before it writes**: `AddFeatureHandlers.plan(_:state:options:)` returns an `AddPlan` (file writes, entitlement merges, a `project.yml` edit closure, `.xcodeproj` manual steps, notes, warnings). `--dry-run` prints it (write / keep / overwrite / merge per file); `execute` applies the YAML edit and entitlement merges in memory first and writes only when both succeed. `ProjectState.scan` reads the project (name and bundle ID from `project.yml` / `project.pbxproj`, platforms, features already present) so `add` writes what `new` would for the same project. `EntitlementsMerger` merges keys into an existing plist, never replaces it
- **ColorDeriver**: one hex → eight light/dark `ColorPair` roles (`primary`, `secondary`, `tertiary`, `onAccent`, three backgrounds, `divider`), every value rounded to 8-bit first. Brightness and saturation are searched until each accent reaches WCAG AA (4.5:1) against `onAccent` and every background in both appearances; dark accents are lighter than light ones, dark `onAccent` is a near-black tint. `primaryVariant` is the pressed shade (brightness × 0.85, LumiKit's factor), emitted only by the standalone `AppTheme`, which uses LumiKit's role names and default status colors
- **LumiKit output targets 1.x** (`DependencyVersion.lumiKit`, emitted as `from:`; 1.0.0 is also the compile floor): `ThemeGenerator` writes `extension LMKTheme { static let <app> = LMKTheme(colors: LMKColorTheme(...)) }` (member name from `ThemeGenerator.themeMemberName(for:)`, only roles that differ from LumiKit's defaults, so no `primaryVariant`, status colors, or fills) and `AppDelegate` calls `LMKTheme.apply(.<app>)`. Tabs subclass `LMKTabBarController` with `LMKTab`s, `Style(prefersSidebarOnIPad: true)` when the app runs on iPad or Mac, and `tabKeyCommandsEnabled = false` on every idiom. Mac Catalyst calls `LMKScene.configureMacWindow` with a minimum size from `AppConstants.MacWindow`, `maximumSize: nil` (full screen and tiling), and `hidesTitleBar: true` (generated apps are device family 1,2, the scaled iPad idiom; the Mac idiom would need `false`); only non-LumiKit apps get `MacWindowConfig.swift`, which also sets a minimum size only. `DesignSystem.swift` defines no cell heights (use `LMKLayout.rowHeight*`). Migration recipes: LumiKit's `docs/MIGRATION-1.0.md`
- **View menu**: a tab app's `AppDelegate.buildMenu(with:)` inserts one `UIKeyCommand` per tab (⌘1…⌘9) plus Refresh (⌘R) into `.view` on every idiom; the commands travel the responder chain to `MainTabBarController.selectTabFromMenu(_:)` / `refreshFromMenu(_:)`, which disable them under a sheet and check the selected tab. Tab-less apps get no `buildMenu`. Localized apps read the titles from the catalog (`AppDelegateGenerator.refreshCommandTitle` is shared with `LocalizationGenerator`)
- **Mac Catalyst entitlements**: every Catalyst app gets `<App>/<App>-MacCatalyst.entitlements` (App Sandbox, outgoing network, plus the iOS capabilities), wired through `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`; a widget is embedded with `destinationFilters: [iOS]`. The iOS `<App>.entitlements` is written when `widget` or `cloudKit` is on
- **CloudKit is opt-in in generated apps**: every CloudKit app (SwiftData or Core Data, sharing or not) reads `cloudKitEnabledKey` from UserDefaults (default off), never syncs when `XCTestConfigurationFilePath` is set, falls back to a local store when the CloudKit store fails to load, and registers for remote notifications only while sync is on. Core Data + CloudKit sets `NSMergePolicy.mergeByPropertyObjectTrump`. Sharing is Core Data only (private + shared stores; accepts on warm and cold launch; posts `AppNotification.cloudKitShareRequiresSync` when sync is off). The privacy manifest declares `CA92.1` for every CloudKit app and `CA92.1` + `C617.1` for LumiKit apps (`PrivacyInfoGenerator.appCategories`)
- **Test serialization rule**: `TestGenerator.appTestsRunSerially(config:)` — Core Data, or SwiftData + CloudKit — drives the generated test file's `.serialized` parent suite, the Makefile's `-parallel-testing-enabled NO`, and the test command in the generated docs (`ProjectDocs`). `ProjectState.disableTestParallelism` mirrors it for `add devTooling`; keep the two in step
- **Shell-out centralized**: All `Process()` calls route through `ShellRunner` (`run` / `runDiscardingOutput` / `runCapturingStdout`). Surfaces `error.localizedDescription` and stderr (stdout when stderr is empty) on failure instead of silently returning `false` like the pre-refactor `XcodeGenRunner`/`PackageResolver`/`ProjectOpener`/`ToolChecker`/git init did. Pipes are drained while the child runs, stderr on a dedicated `Thread`: never a GCD global queue, whose width the cooperative pool shares, so a parallel test run that blocks every cooperative thread in `run` would starve the reader and hang. `--verbose` (`ShellRunner.isVerbose`) streams child output
- **Output streams**: progress on stdout via `print`; every warning and error on stderr via `Console.warn` / `Console.printError`. Failures throw (ArgumentParser prints `Error: …` to stderr and exits 1) instead of printing and returning: `OverwriteProtection.RefusedError`, `IncompleteGenerationError` (xcodegen failed in `.xcodeproj` mode; output kept), `ProjectYamlEditError` (`add`), `ExitCode.failure` (`doctor`), `ExitCode(1)` (declined overwrite), `ExitCode(130)` (Ctrl-C)
- **Logging core**: `LogCoreGenerator` holds the reference copy of the shared `<Prefix>Log` core as two raw-string templates between `// BEGIN LOG CORE TEMPLATE` / `// END …` and `// BEGIN LOG CORE TESTS TEMPLATE` / `// END …` markers (tokens `__PREFIX__`, `__SUBSYSTEM__`, `__MODULE__`; rendering is substitution only). The literals sit at column 0 with SwiftFormat's `indent` and `docComments` disabled around them; keep the opening `static let … = #"""` line right after the BEGIN marker and the closing `"""#` right before the END marker. Generated apps don't get the core: they log through `LMKLogger` (LumiKit) or a shared `Logger.app` declared in `AppConstants`
- **CLI output symbols** live in `UISymbols` (✓ ✗ ⚠ ↻ ─ ↑). Never hard-code `"\u{2713}"` inline
- **Ctrl-C cleanup**: `NewCommandRunner` arms `SignalHandler.install()` only around `generate()` and only when the output directory didn't exist before. The handler is async-signal-safe: it sets a `sig_atomic_t` flag and restores `SIG_DFL` (a second Ctrl-C kills at once), nothing else. `FileWriter.writeFile` calls `SignalHandler.throwIfInterrupted()` before each write (gated by the `guardsWrites` task-local, so a test's SIGINT can't stop another test's writes); the runner catches `InterruptedError`, removes the partial output, and throws `ExitCode(130)`. It runs the same removal when `generate()` throws (never for a pre-existing directory, never for `IncompleteGenerationError`). Git init, resolve, and open run after `uninstall()`. The wizard's raw-mode Ctrl-C raises SIGINT under the default action (exit 130 after the terminal is restored)
- **Wizard input**: raw-mode prompts edit through `LineEditor` (grapheme-aware cursor, multi-byte UTF-8 held until complete, unhandled escape sequences dropped whole); yes/no prompts use editline (`CEditLine`). `<` or the up arrow goes back ("back" is an ordinary answer). `NewCommandWizard.requireTerminal()` refuses to start without a TTY; end of input throws `PromptEngine.InputClosedError` instead of looping. Flags passed to an interactive run prefill and skip their steps

### Commands

```bash
monolith new app       # Create iOS app (interactive or --no-interactive)
monolith new package   # Create Swift Package
monolith new cli       # Create Swift CLI
monolith list features # List available features (--type app|package|cli)
monolith add <feature> # Add feature to existing project (--path, --dry-run, --force, --license, --bundle-id, --locales)
monolith doctor        # Check tool availability (exits non-zero only without swift)
monolith completions   # Generate shell completions (zsh|bash|fish)
monolith version       # Print version
```

### Shared flags on `new` commands

`--preset` (minimal/standard/full; unioned into `--features`), `--force` (overwrite protection), `--open` (open in Xcode), `--resolve` (`swift package resolve`, or `xcodebuild -resolvePackageDependencies` for apps), `--save-config`/`--load-config` (JSON config files), `--dry-run`, `--no-interactive`, `--output`, `--verbose` (stream child-process output), `--license` (mit/apache2/proprietary — defaults: app=proprietary, package=mit, cli=apache2), `--git`/`--no-git` (mutually exclusive; without the wizard, off unless `--git`)

- **`--load-config`** is the whole config: `NewCommandOptions.validateLoadConfig` rejects config-shaping flags (`--name`, `--preset`, `--license`, `--git`/`--no-git`, and each command's own, such as `--features`); operational ones (`--output`, `--force`, `--dry-run`, `--open`, `--resolve`, `--verbose`, `--save-config`, `--no-interactive`) are allowed. Config files carry `schemaVersion` (`ConfigFile.currentSchemaVersion`; newer is rejected, missing means pre-schema) and `monolithVersion`, are written with sorted keys, warn on unknown keys, and must match the command's project type
- **Presets** (`Preset`): standard = devTooling, gitHooks, claudeMD (+ privacyManifest for apps); full = every `AppFeature.promptOptions` entry minus `rSwift`, `fastlane`, and `swiftData` (Core Data is the layer CloudKit sharing needs), every package/CLI feature minus the no-op `strictConcurrency`
- **`new app`** adds `--platforms` (default `iPhone,iPad`; sets `TARGETED_DEVICE_FAMILY` via `AppConfig.targetedDeviceFamily`, Catalyst counts as iPad), `--locales`, `--category`, `--tabs`, and the package-wiring flags below
- **`new cli`** adds `--no-argument-parser` (ArgumentParser is on by default). A CLI is a library `<TypeName>Kit` (`Sources/<TypeName>Kit/<TypeName>.swift`) plus a thin `Sources/<name>/main.swift`, with smoke tests in `Tests/<TypeName>KitTests/`; `commandName` is the binary's name as typed

### Package-only flags for multi-target frameworks

- `--targets` entries suffixed `:exec` become `.executableTarget` siblings: they depend on swift-argument-parser, default to a `run` subcommand, and get no `Tests/` fixture. A package with an executable keeps `Package.resolved` tracked.
- `--package-deps` (comma-separated): cross-cutting deps auto-merged into every target's dependency list. Resolves like `--target-deps`.
- `--test-helper-targets` (comma-separated): test-helper library targets — typically a `<Name>Testing` sibling (e.g. `MultiLibTesting`) consumed by adopter test targets. Generates a Swift Testing stub source file (`import Testing`, public expectations namespace) instead of the plain library placeholder, and skips the auto-generated `Tests/<name>Tests/` fixture (these libraries exist to be consumed, not tested in isolation). No `linkerSettings` — Swift Testing is bundled with the toolchain; XCTest interop is opt-in (add `import XCTest` to the source, `swift test` links it on demand).
- `--target-resources` (`"Target:dir1,dir2;..."`): emits `resources: [.process(...)]` per target.
- `--main-actor-targets`: targets that get `.defaultIsolation(MainActor.self)`; a non-empty list adds the `defaultIsolation` feature (`PackageConfig.init`), which drives the xcodebuild Makefile and docs. With `defaultIsolation` and no list, the only library target gets it (`NewPackageCommand.defaultMainActorTargets`).
- **Build mode**: `PackageConfig.requiresXcodebuild` (defaultIsolation with targets, or any dep in `KnownPackages.uikitOnlyProducts`) switches the Makefile and docs to xcodebuild on a simulator (`IOS_VERSION` knob, `<Name>-Package` umbrella scheme when `xcodeBuildScheme` says so).
- **Platforms**: `PlatformVersion.spmDeclaration` emits `.iOS(.v18)` only when tools-version 6.2 has the constant, else the string form (`.iOS("18.4")`). `PackageConfig.mergingRequiredPlatforms` raises declared platforms to wired deps' floors and adds only macOS (the higher of the dep's floor and the log core's) when undeclared.

### Package wiring

- **`--use-packages`** (`"Name[:version],..."`): built-in registry, **`new app` only**. Currently registered: `SnapKit`, `Lottie`, `LookinServer`. Bare identifier uses the registry's default version; optional `:version` overrides per call. `ExternalPackage.parseUsePackages(_:)` synthesizes `ExternalPackage` entries from `KnownPackages.registry` (Config/KnownPackages.swift), and `NewAppCommand` appends each to the target deps, so they're linked without repeating them. Adding a new well-known package is a registry entry, not a generator change. Unknown identifier → config-time error with a "did you mean…?"; `LumiKit` and `ArgumentParser` (internal entries, `exposeViaUsePackages: false`) are rejected with a pointer to `--features lumiKit` / `--external-packages`.
- **`new package` resolves registry products by name**: a `--target-deps` / `--package-deps` entry naming any `KnownPackages.allProducts` member (SnapKit, Lottie, LookinServer, the five LumiKit products) gets the registry URL and version with no `--external-packages` entry. `--external-packages` is for anything else, or to override a registry package's version or location.
- **`--external-packages`** (`"Name=url:requirement[:packageName];..."` URL form, or `"Name=path[:packageName]"` path form): declares SPM packages outside the registry. A URL is anything with `://` or an scp-style `user@host:` prefix (`git@github.com:owner/repo.git`); `requirement` is verbatim SPM (`from: "0.1.0"`, `branch: "main"`, `exact: "1.0.0"`, etc.) and starts at the first `:` after the scheme or scp host. Path form has no requirement segment (paths are unversioned) and no `://` — the literal token is the path, so it is `LumiKit=../LumiKit`, **not** `LumiKit=path:../LumiKit` (that would set the path to the string `path:../LumiKit`). Externals override built-ins: `--external-packages 'LumiKit=../LumiKit'` replaces Monolith's default GitHub URL with a local path. Path-form entries emit `.package(name:path:)` in `PackageSwiftGenerator` and `path:` in XcodeGen YAML, with absolute paths made project-relative (`XcodeGenGenerator.normalizePath`). The parsers live in Config/ExternalPackage.swift (`ExternalPackage.parse(_:)`, `parseUsePackages(_:)`); `validationProblem` catches what a config file can smuggle past them.
- **`--target-deps` on `new app`** (comma-separated products to link into the app target): `XcodeGenGenerator.routeProductToPackage` resolves direct match against an external's `name` → longest-prefix match (`ExtPkgCore` → `ExtPkg`) → registry product (`LumiKitDebug` → `LumiKit`) → single-external fallback → `product=package`. `AppConfig.validate()` then requires every dep to resolve (feature-wired products, an external, or a route to one), reports typos and bare package names (`KnownPackages.productSuggestions`) and unwired registry products (with the flag that would wire them), and requires every external to be linked by some routed dep or by a feature (LumiKit/Lottie overrides). Errors: `externalPackageNotConsumed`, `misspelledProduct`, `unwiredKnownProduct`, `unknownTargetDependency`, `duplicateExternalPackageNames`, `externalPackageCollidesWithTarget`. Platform conditionals come from the registry (LookinServer is iOS-only → `platforms: [iOS]` in XcodeGen YAML, `condition: .when(platforms: [.iOS])` plus a `#if canImport` guard in a package).
- **Multi-product externals on `new package`**: the must-be-consumed check matches on the external's `name`, and `--target-deps` names *products*. Declare one entry per consumed product with the `:packageName` tail (`'LumiKitCore=../LumiKit:LumiKit;LumiKitUI=../LumiKit:LumiKit'`); `collectExternalDependencies` de-dupes them into one `.package(...)` line. `PackageConfig.validate()` errors include `externalPackageNotConsumed`, `misspelledExternalProduct`, `duplicateExternalPackageNames`.

### App Features (26)

Data: `swiftData`, `coreData`, `cloudKit`, `cloudKitSharing`
UI / third-party: `lumiKit`, `lottie`, `darkMode`, `combine` (an `AsyncService` Task-cancellation template; no Combine code)
System: `notifications`, `deepLinks`, `spotlight`, `deferredLaunchWork`, `widget`, `localization`
App Store hygiene: `privacyManifest`, `appIconValidation` (script run by `make check` and `make archive`, not a build phase)
Tooling: `devTooling`, `gitHooks`, `coreDataAuditHook`, `claudeMD`, `licenseChangelog`
Legacy (XcodeGen only): `rSwift`, `fastlane` (the only feature that writes `ExportOptions.plist`)
No-op for cross-target symmetry: `strictConcurrency` (accepted on `new app` so adopters who also pass it on `new package` / `new cli` aren't surprised; warns on stderr at swift-tools-version 6.2 where strict concurrency is already the language default; not offered by the wizard)
Auto-derived: `tabs`, `macCatalyst`, `coreDataAuditHook` (rejected in `--features`), plus `darkMode` (from lumiKit, also selectable), `cloudKit`, `coreData` (see Key Patterns)

**Moved to the `--use-packages` registry**: `snapKit` → `--use-packages SnapKit`, `lookin` → `--use-packages LookinServer`. Promoted to the `KnownPackages` registry in v0.3.0; the auto-translating shim ran for one minor version and was removed in v0.4. The CLI now raises an error listing the migration (`KnownPackages.removedFeatureAliases`) when these tokens show up in `--features`. The principle: `--features` is for code-shaping integrations (LumiKit's theme + LMKNavigationController + LMKLogger; Lottie's `LottieHelper.swift` template); the registry is for "just wire the dep" cases.

Not recommended: `rSwift` (XcodeGen only, inactive development — Xcode 15+ has native type-safe resources), `fastlane` (XcodeGen only, prefer Makefile or Xcode Cloud)

### `monolith add <feature>` — retrofit features into an existing project

Two tiers, both invoked as `monolith add <feature> [--path <dir>] [--dry-run] [--force]`:

- **Tier 1 — file writes (any project system)**: `devTooling`, `gitHooks`, `claudeMD`, `licenseChangelog` (`--license`), `privacyManifest`, `appIconValidation`
- **Tier 2 — app projects only**: `localization` (`--locales`), `macCatalyst`, `lottie`, `widget`. On XcodeGen projects, the command edits `project.yml` in place (idempotent — re-running is a no-op; works with `schemes:` blocks); re-run `xcodegen generate` afterward. On `.xcodeproj` projects, the files are written and the command prints the manual integration steps.

Rules (see the `AddPlan` pattern above):
- **Existing files are kept** unless `--force` (`FileWriter.ExistingFilePolicy`). Entitlements are always merged (`EntitlementsMerger`), even with `--force`.
- **A failed `add` writes nothing**; `--dry-run` reports write / keep / overwrite / merge per file.
- **The project is read, not the directory**: `ProjectState.scan` takes the app name and bundle ID from `project.yml` or `project.pbxproj`, and the path is standardized, so `--path .` works. A package with an executable target next to its libraries is a package, not a CLI.
- **`add` matches `new`**: `devTooling` (serial tests per the rule above, icon/string checks), `gitHooks` (model reminder for CloudKit apps), `claudeMD`, `privacyManifest`, and `macCatalyst` render through the same generators with the scanned state.
- `widget` uses the app's bundle ID from the project (`<id>.Widget`, App Group `group.<id>`); `--bundle-id` applies only when the project sets none (a conflicting flag warns and is ignored); default `com.example.<appname>`. It merges the App Group into the app's (and the Mac Catalyst) entitlements and, on a Catalyst app, filters the widget embed to iOS.
- `macCatalyst` writes `<App>-MacCatalyst.entitlements` (the iOS entitlements plus sandbox and network), sets `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`, an App Category, and iPad in the device family when missing; on a LumiKit app it writes no `MacWindowConfig.swift` and prints the `LMKScene.configureMacWindow` call instead. `MacWindowConfig` inlines its minimum size when the app has no `AppConstants.MacWindow`.

(Removed in v0.4: `snapKit`, `lookin`. Retrofit those via Xcode → File → Add Package Dependencies… against the URLs in `KnownPackages.registry`.)

The other app features (`swiftData`, `coreData`, `cloudKit`, `cloudKitSharing`, `lumiKit`, `darkMode`, `combine`, `notifications`, `deepLinks`, `spotlight`, `deferredLaunchWork`, `tabs`, `rSwift`, `fastlane`, `coreDataAuditHook`, `strictConcurrency`) and the package feature `defaultIsolation` require editing existing `AppDelegate.swift`/entitlements/Info.plist/Package.swift in ways that depend on user-modified content. Best path: re-scaffold with the new feature set into a temp dir and cherry-pick the diff.

### Generator no-ops

- `strictConcurrency` (App + Package + CLI feature): no-op at `swift-tools-version: 6.2`. The legacy `.enableExperimentalFeature("StrictConcurrency")` shim is obsolete; strict concurrency is the language default. Flag still accepted (config backwards-compat) but generates no `swiftSettings` entry. `NewCommandRunner` emits a stderr warning when it's set; the `full` preset and the app wizard leave it out.

## Build & Test

```bash
swift build                           # Build
swift test                            # Run all tests
swift run monolith version            # Quick smoke test
swift run monolith new cli --name X --no-interactive  # Generate CLI
swift run monolith new package --name X --no-interactive  # Generate Package
swift run monolith new app --name X --no-interactive  # Generate App (needs xcodegen)
```

## Testing

- **Swift Testing** framework (`@Test`, `#expect`, `@Suite`), raw-identifier test names (`` func `generated project passes its own lint and format checks`() ``)
- Tests mirror source structure: `Tests/MonolithTests/{Commands,Config,Generators,Prompts,Utilities}/`
- Integration tests generate projects to temp dirs and verify file existence. Anything that writes a project, changes the working directory (`withTempDir`), or installs the SIGINT handler nests under `MonolithIntegrationSuite` (`@Suite(.serialized) enum`), since `.serialized` is per-suite. Tests that run xcodegen use `.enabled(if: xcodegenAvailable)`
- Generated output is string-based — test with `output.contains(...)` assertions
- Integration test coverage matrix (which option is verified by which test, plus combinations with distinct output and the whole-project checks) lives in [README.md](../README.md#integration-test-coverage)
- **Generic placeholder names in tests**, never internal project names. Use `MultiLib` / `MultiLibCore` / `MultiLibUI` / `MultiLibTesting` etc. for multi-target framework fixtures, and `ExtPkg` for an arbitrary external SPM package. Avoid Causeway / Prism / Plantfolio / Petfolio — those are workspace-internal and shouldn't leak into Monolith (a general-purpose tool).

### Substring-only assertions are not enough

`yml.contains("string")` and `pkg.contains("...")` style assertions can pass against output that's syntactically broken or semantically wrong. Two historical examples (May 2026): xcodegen YAML emitted `preBuildScripts:` at column 0 instead of nested under the target — every `devTooling` app's `project.yml` was unparseable, yet the substring assertion passed. Similarly, `- package: LumiKit` matched `yml.contains("LumiKit")` but LumiKit has no product named `LumiKit` (the actual products are `LumiKitCore` / `LumiKitUI` / `LumiKitPhoto` / `LumiKitDebug` / `LumiKitLottie` as of 1.0), so xcodebuild failed with "Missing package product".

When a new feature's output has structural meaning (YAML indentation, init chains, import lines, package products), add a **structural** assertion alongside the substring one. Parse the YAML, regex over indentation, check the exact line sequence — whatever proves the output is actually well-formed, not just contains a known token.

### Build-the-output verification

Substring tests don't run xcodegen or xcodebuild against the generated project, so compile-time errors in the templates (Sendable conformance, init inheritance, missing imports) only surface when an adopter scaffolds and tries to build.

- **Lint gate (automated)**: `GeneratedOutputLintTests` renders a matrix of apps, packages, and CLIs through the real `new` commands (`--project-system xcodegen`, so no xcodegen run) and holds each to `swiftlint --strict` and `swiftformat --lint`, as its own `make check` would; it skips when either tool is missing. A generator change that breaks a fresh project's `make check` fails here. Add a fixture when a new feature or shape isn't covered.
- **Build (manual)**: when changing any generator that emits Swift code or `project.yml`, regenerate at least one affected fixture and run `xcodegen generate && xcodebuild -quiet build -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`. The `LintFixture` list in `GeneratedOutputLintTests` and the configs in `IntegrationTests.swift`, `AppFeatureIntegrationTests.swift`, and `PackageCLIIntegrationTests.swift` make a convenient corpus; regenerate any subset into a scratch dir (e.g. `/tmp/monolith-test-projects/`) and build them.

## SwiftLint & SwiftFormat

Run `make check` to verify both. Pre-commit hook (`Scripts/git-hooks/pre-commit`) runs them automatically.

Monolith's own `.swiftlint.yml`, `.swiftformat`, `Brewfile`, and pre-commit hook are byte-for-byte what `monolith new cli --features devTooling,gitHooks` writes. Only the hook is test-enforced (`Monolith's own hook is the template's output`): change a template, then regenerate the matching file here in the same commit.

The hook checks added, copied, modified, and renamed files, passes paths NUL-separated (`xargs -0`), and fails when a tool is missing. `GitHooksBehaviorTests` runs the generated script in a scratch repository with stand-in tools, because a string check cannot tell a script that mentions `xargs -0` from one that hands a path through whole. In the Swift template a backslash needs doubling (`'\\0'` in the literal is `'\0'` in the script).

Generated configs (`SwiftFormatGenerator`, `SwiftLintGenerator`):
- `.swiftformat` opens with `--min-version` (`ToolVersion.swiftformatFloor`, 0.62.0, the same floor as the Brewfile comment), spells every option in kebab-case (`--trailing-commas collections-only`, `--self remove`, `--indent 4`, `--swift-version 6.2`), and lists only rules that differ from SwiftFormat's defaults (enables `unusedPrivateDeclarations`, `isEmpty`, `preferFinalClasses`, …; disables `wrapIfStatementBodies` / `wrapIfExpressionBodies` / `wrapPropertyBodies`, …). `--exclude` covers `.build,Build,build` plus `<App>/Generated` and `fastlane` for R.swift/fastlane apps
- `.swiftlint.yml` lints `Sources` + `Tests` (apps: the app, test, and widget dirs, matching the hook), `check_for_updates: false`; force unwrapping and force casting are warnings (not allowed in any committed code)
- Trailing commas mandatory on collection literals
- `@Test` method names should NOT be prefixed with `test` (SwiftFormat's `swiftTestingTestCaseNames` strips it and turns `@Test("…")` into a raw-identifier name)

---

*Optimized for Claude Code.*
