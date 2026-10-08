# Changelog

All notable changes to Monolith will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

**Generated apps**
- **Mac Catalyst apps get their own entitlements file**, `<App>-MacCatalyst.entitlements`, used for Mac builds only: App Sandbox (which the Mac App Store requires), outgoing network access, and the app's iOS capabilities.
- **Mac Catalyst apps get `make build-catalyst`, `make archive-mac`, and `make release-mac`.** With `appIconValidation`, `make archive` checks the icon before it archives.
- **Tab apps reselect the tab the user left** when the system restores the scene.
- **Core Data sharing apps post `AppNotification.cloudKitShareRequiresSync`** when the user opens a share while sync is off, so the app can ask them to turn it on.
- **CloudKit apps document the schema rules**: the generated CLAUDE.md lists which changes stay safe once the schema is in Production, and the README notes the deploy step.
- **Info.plist declares `ITSAppUsesNonExemptEncryption` as `NO`**, with a comment on when to change it.

**Generated packages**
- **Generated packages carry a logging core.** `new package` writes `Sources/<Target>/Logging/<Prefix>Log.swift`, a `<Prefix>Log+Categories.swift` starter with a `general` category, and `<Prefix>LogTests.swift` in that target's tests. The core wraps `os.Logger` with six levels (`debug` through `fault`), a runtime `minimumLevel` that never filters out errors and faults, a `handler` for forwarding entries to an app's own store, public message text with user data passed separately as `private:`, error summaries by domain and code, and `once(_:)` for failures on per-frame or polling paths. Its write functions are `package`, so every target in the package can log through it and consuming apps cannot. It goes in the library target named after the package, or else the first library target with no in-package dependencies; the prefix comes from the package name, and the subsystem is a `com.example.<name>` placeholder to replace with your own identifier. The generated CLAUDE.md explains how to use it. The core needs iOS 16, macOS 13, Mac Catalyst 16, tvOS 16, watchOS 9, or visionOS 1: a package that declares a lower deployment target is generated without it (with a warning), and a package that declares no macOS version gets macOS 13, or a wired dependency's higher macOS floor, so `swift build` on a Mac compiles it.

**Generated tooling and docs**
- **New CHANGELOGs link `[Unreleased]`** to the project's commits on GitHub, at the same guessed repository URL the generated README uses, unless the project is proprietary, git has no author name, or the name has non-ASCII letters (dropping them would point at someone else's account).

**`monolith add`**
- **`--force`** replaces files that already exist. Without it, `add` keeps them.
- **`add localization --locales`** sets the catalog's locales, as `new app --locales` does.
- **`add localization`, `add macCatalyst`, and `add appIconValidation` say when the existing Makefile lacks their targets**, and how to regenerate it.
- **`add macCatalyst` writes the Mac entitlements file** that `new` writes, holding the app's iOS entitlements as well. On XcodeGen projects it also sets an App Category and adds iPad to the device family when they are missing; on `.xcodeproj` projects it prints those steps.

**The CLI**
- **`--verbose` on `new app`, `new package`, and `new cli`** streams the output of xcodegen, git, package resolution, and `open` as they run. Failure messages still quote the captured output.
- **The package and CLI wizards have a preset step**, like the app wizard.
- **Saved config files record a schema version and the Monolith version that wrote them.** A file from a newer schema is rejected with a message.

### Changed

**Generated apps**
- **Generated apps target LumiKit 1.0.0** instead of 0.9.0, and their code is written against the 1.0 API, so it no longer builds against a 0.x LumiKit. The requirement is emitted as `from:`, so a project resolves any 1.x release.
  - The theme is an `LMKTheme` value declared in `<App>Theme.swift` (`extension LMKTheme { static let myApp = LMKTheme(colors: LMKColorTheme(...)) }`) and applied at launch with `LMKTheme.apply(.myApp)`. It passes only the color roles that differ from LumiKit's defaults, so `primaryVariant`, the status colors, and the fills follow LumiKit.
  - A tabbed app's `MainTabBarController` is an `LMKTabBarController` built from `LMKTab`s: each tab's screen is created the first time the tab is selected, the bar follows the theme, and regular-width iPad and Mac windows show the tabs in a sidebar.
  - A Mac Catalyst app sets up its window with `LMKScene.configureMacWindow` and no longer gets a `MacWindowConfig.swift`. Apps without LumiKit keep it. `add macCatalyst` does the same: on an app that links `LumiKitUI` it writes no `MacWindowConfig.swift` and prints the `LMKScene.configureMacWindow` call to add instead.
  - `DesignSystem.swift` no longer defines cell heights; use `LMKLayout.rowHeight`, `.rowHeightCompact`, and `.rowHeightComfortable`.
  - `--target-deps` and the package dependency checks know the 1.0 products: `LumiKitPhoto` is new, and `LumiKitNetwork` is now `LumiKitDebug`.
- **The SnapKit default moved to 6.0.0 in lockstep with the LumiKit pin.** LumiKit 1.0.0 requires SnapKit `from: 6.0.0`, so a scaffold pinning SnapKit 5.x alongside it would fail dependency resolution; the two floors move together. The Lottie default moved to 4.6.1 as routine catch-up to the current release, which also satisfies LumiKit's own Lottie requirement.
- **The default platforms are iPhone and iPad, and `--platforms` sets the device family.** `--platforms iPhone` now makes an iPhone-only app; before, every app was universal whatever the flag said.
- **CloudKit sync is opt-in in every CloudKit app**, SwiftData or Core Data, with or without sharing (0.5.0 did this for sharing apps only). Sync starts once the user turns it on, never runs in test runs, and falls back to a local store when the CloudKit store fails to load. The app registers for remote notifications only while sync is on, and its privacy manifest declares UserDefaults (`CA92.1`) for the preference.
- **Tests run one at a time in Core Data apps and in SwiftData apps that sync through CloudKit**, the same way in the generated test suite, `make test`, and the documented test command. A Core Data app without CloudKit now runs serially too; plain SwiftData apps keep the parallel run.
- **SwiftData apps list their models once, in `AppSchema.models`**, which both the app's container and the test container read. The container is handed to every tab's screen, or to the root screen of an app without tabs.
- **Tab apps get a View menu on every idiom**, not only on Mac Catalyst: one command per tab (⌘1…⌘9) and Refresh (⌘R). They are menu items on the Mac and the iPad menu bar and keyboard shortcuts everywhere, are disabled while a sheet is up, and mark the current tab. Apps without tabs no longer get a menu.
- **Mac Catalyst windows have a minimum size and no maximum**, so full screen and wide window tiling work.
- **Sample screens follow Dynamic Type and use the spacing tokens and the safe area**; a tab's screen shows a placeholder instead of a blank view.
- **Generated themes meet WCAG AA for text.** Every derived accent reaches 4.5:1 against its `onAccent` color and against each background, in light and dark mode. Dark-mode accents are now lighter than the light-mode ones instead of darker, and dark-mode `onAccent` is a near-black tint, so titles on accent fills stay readable.
- **The standalone `AppTheme` uses LumiKit's role names** (`primaryVariant`, `onAccent`, `outline`, `fill`, `fillStrong`) and LumiKit's default status colors, so moving to LumiKit is a type rename. It drops `photoBrowserBackground`, `white`, and `black`.
- **Generated apps log failures instead of printing them.** The APNs registration failure, the SwiftData container failure, and CloudKit share-acceptance failures use `LMKLogger` when LumiKit is enabled and a shared `Logger.app` otherwise, with the error description marked private. `print` output never reaches the unified log on a device.
- **`LottieHelper` plays looping animations once under Reduce Motion** and pauses them while the app is in the background.
- **`L10n` constants carry a default value and a translator comment**, and the generated String Catalog includes the same comments.
- **`make release` archives the app and opens the archive in Xcode's Organizer** to upload from there. `ExportOptions.plist` is generated only for fastlane, whose `beta` lane uses it.
- **App targets with dev tooling set `ENABLE_USER_SCRIPT_SANDBOXING` to `NO`**, which their SwiftLint and SwiftFormat build phases need, and generated XcodeGen projects declare Xcode 26.0.
- **Apps ignore `Local/` in git.**

**Generated packages**
- **Packages with an executable target keep `Package.resolved` under version control**; library-only packages still ignore it.
- **Package Makefiles take the `IOS_VERSION` setting** that app Makefiles have, and `make help` names the build mode actually used (`swift build` or xcodebuild).

**Generated CLIs**
- **A generated CLI is a library, `<Name>Kit`, plus a thin `main.swift` executable**, so tests can import the command. It ships smoke tests instead of an empty suite.
- **`new cli` includes swift-argument-parser by default**; pass `--no-argument-parser` for a plain executable.
- **Generated packages and CLIs use swift-argument-parser 1.8.2.**

**Generated tooling and docs**
- **The generated pre-commit hook fails when SwiftLint or SwiftFormat is not installed**, where it used to print a warning and let the commit through. A check that is skipped reads as one that passed, and the same commit fails `make check` or CI anyway. `git commit --no-verify` remains the way around it.
- **Generated Brewfiles now pin SwiftFormat at 0.62.0+** instead of 0.54+. The generated `.swiftformat` names rules that 0.54 does not know: `preferFinalClasses`, `redundantThrows`, and `redundantAsync` arrived in 0.58.0, `redundantMemberwiseInit` in 0.59.0, `redundantVariable` was renamed from `redundantProperty` in 0.60.1, and `wrapIfStatementBodies` / `wrapIfExpressionBodies` split out of `wrapConditionalBodies` in 0.62.0, so an older install rejects the config outright. The Brewfile pin is a floor comment, so `brew bundle` still installs the latest release. The generated `.swiftformat` now declares the same floor with `--min-version`, so an older SwiftFormat stops with a message that names it.
- **The generated `.swiftformat` keeps one-line `if` bodies and skips `build/`.** SwiftFormat 0.63 turns `wrapIfStatementBodies` and `wrapIfExpressionBodies` on by default, which rewrap `if x { return y }` onto three lines; the config now disables both, as it already did `wrapPropertyBodies`. `--exclude` gains a lowercase `build` beside `Build`, since the match is case-sensitive and a `-derivedDataPath build/...` puts package checkouts in the tree, which `swiftformat --lint .` then lints. Options are now spelled in kebab-case, and only rules that differ from SwiftFormat's defaults are listed.
- **Generated SwiftLint configs lint test sources (and the widget's) too**, as the pre-commit hook does, and no longer check for a SwiftLint update on every run.
- **Generated docs**: package docs lead with the `make` targets when a Makefile exists, every raw xcodebuild line in them is quiet, and app and CLI READMEs gained a License section and list each setup step once.

**`monolith add`**
- **`add` keeps files that already exist** instead of overwriting them; pass `--force` to replace them. Entitlements are always merged, never replaced.
- **`add --dry-run` lists, file by file, whether it would write, keep, overwrite, or merge.**

**The CLI**
- **Failures now exit non-zero.** Each of these printed an error and exited 0, so a script could not tell it from success:
  - a non-interactive `new` refusing to write into a non-empty directory without `--force`;
  - declining the overwrite prompt. It now says nothing was written and exits 1;
  - xcodegen failing in `.xcodeproj` mode. The "app created" message no longer prints; the rest of the app stays on disk with its `project.yml`, the error says how to finish, and any requested git init, package resolve, or open is skipped;
  - `doctor` with a required tool missing;
  - `add` when `project.yml` cannot be updated. A failed `add` now writes nothing, so the project stays as it was.
- **Warnings and errors go to stderr**; progress stays on stdout. This covers failed shell-outs (git, xcodegen, package resolution, `open`), the overwrite warnings, the skipped-resolve note, the `MacWindow` hint from `add macCatalyst`, and the interrupt message.
- **A failed generation removes its partial output**, as Ctrl-C already did: when a `new` command fails partway, the project directory it created is deleted. A directory that existed before the run is never removed.
- **App names must be Swift identifiers** (an ASCII letter, then letters, digits, or underscores), since they become type and module names. Package and CLI names may also use hyphens. All names must be ASCII.
- **One persistence layer per app**: `swiftData` with `coreData`, and `swiftData` with `cloudKitSharing` (which needs Core Data's shared store), are rejected with the reason, and the wizard asks again.
- **`new app --project-system spm` is now rejected instead of silently generating an Xcode project.** It was accepted as a backward-compatibility alias and mapped to `xcodeproj`, so the flag asked for one thing and produced another with no warning. SPM can't back an app target (an executable target carries no code signing, entitlements, or capabilities), so the flag now fails with that reason and points at `new package` / `new cli`. `--load-config` is covered too: a config file carrying `"projectSystem": "spm"` previously generated a `Package.swift` "app". `new package` and `new cli` are unaffected; SPM remains their project system.
- **`new app` checks its package wiring**: `--target-deps` rejects unknown or misspelled products and products whose package nothing adds, every `--external-packages` entry must be linked by some product, and `--use-packages` rejects LumiKit and ArgumentParser and names the flag that wires them.
- **`--features tabs`, `macCatalyst`, and `coreDataAuditHook` fail with a message** naming the input that drives them (`--tabs`, `--platforms`, or the features that derive the hook).
- **`--load-config` sets the whole config**: options that set part of it, such as `--name` or `--features`, are rejected instead of ignored. Saved files are deterministic, a file with an unknown key loads with a warning, and a file saved by another `new` command is rejected.
- **`--git` and `--no-git` can no longer be passed together.**
- **The wizard needs a terminal**: it refuses to start when stdin is not one. Type `<` or press the up arrow to go back; "back" is now an ordinary answer. The app wizard no longer offers `strictConcurrency`, which has no effect.
- **`doctor` says what each tool is for and marks xcodegen as required for `new app`.** A missing xcodegen is reported without failing `doctor`.

### Removed
- **`make export` and `make upload` in generated app Makefiles.** `make release` opens the archive in Xcode's Organizer instead, which signs and uploads it.
- **The generated `AppDelegate`'s empty post-launch `Task` and its memory-warning relay.**

### Fixed

**Generated apps**
- **`--preset full` generated an app that didn't build**: it selected SwiftData and Core Data together. It now uses Core Data, the layer CloudKit sharing needs.
- **Core Data + CloudKit apps could lose a save that raced a sync import.** Only sharing apps set a merge policy; every CloudKit Core Data app sets one now.
- **A SwiftData app moved its store when it later gained an App Group**, for example by adding a widget, leaving its existing data behind. The store location is now pinned.
- **The SwiftData sample model broke CloudKit's schema rules** in apps that sync: its attributes had no default values. Its test container could also sync test data to iCloud on a signed run; it never syncs now.
- **SwiftData apps logged a page of Core Data errors on their first launch.**
- **Core Data sharing apps ignored a share opened while the app wasn't running**, and a failed accept went unreported.
- **Spotlight results and notification taps that launched the app could go nowhere**, because they arrived before the UI was up. They are now held until it is, then routed through the root view controller.
- **Deferred launch work ran every time the app became active**; it now runs once per launch.
- **A tabbed app showed an empty navigation bar above every tab's own bar.** The tab bar controller was wrapped in a navigation controller although each tab already has one; it is now the window's root.
- **A Mac Catalyst app with a widget didn't build for the Mac.** The widget is now embedded in iOS builds only.
- **The `combine` feature's `AsyncService` kept every task until `cancelAll()`**; it now releases each one when it finishes.
- **The generated `LottieHelper` drew Swift concurrency warnings on every build**, because it created main-actor Lottie views from a nonisolated context. It is now main-actor isolated.
- **Some fresh apps failed their own `make check`**: SwiftData apps (test helpers without a final newline) and apps using the standalone `AppTheme` or `AsyncService` (SwiftFormat violations).
- **The app-icon check let fully opaque RGBA icons through**, which App Store Connect rejects, and its verdict depended on how the PNG was encoded. It now fails on any alpha channel or `tRNS` chunk and skips the tinted and macOS icon slots, which may be transparent.
- **The localization audit flagged Xcode's "Don't Translate" and key-as-source entries**, and ignored precision and unsigned format specifiers such as `%.1f` and `%lu` when comparing placeholders.
- **Privacy manifests in LumiKit apps declared no required reasons**, although LumiKit reads UserDefaults and file timestamps; they now declare `CA92.1` and `C617.1`. In the commented snippets, the disk-space entry suggested `85F4.1`, which only covers showing free space to the user; checking free space before writing files is `E174.1`. The file-timestamp entry suggested `3B52.1` (files the user picked) and now suggests `C617.1` (the app's own containers).
- **SwiftData + CloudKit apps got the Core Data model reminder in their pre-commit hook**, which never fires for SwiftData; they now get a reminder when a SwiftData model changes.
- **R.swift and fastlane apps ran SwiftFormat over `<App>/Generated` and `fastlane`**, which SwiftLint already skipped.

**Generated packages**
- **Package manifests lowered deployment targets that have a minor version**: `iOS 18.4` became `.iOS(.v18)`. Such versions are now written as strings (`.iOS("18.4")`), and only platform constants that exist are used.
- **A package that depends on SnapKit or LumiKit gained platforms it never declared**, such as tvOS. Only declared platforms are raised now, plus macOS so `swift build` works on a Mac.
- **A package that depends on a UIKit-only product such as `LumiKitUI` failed `make build` and `make test`** unless it also used `defaultIsolation`. It now builds and tests with xcodebuild, and its docs say so.
- **A package's executable target printed its help when run with no arguments** instead of running its default `run` subcommand.
- **LookinServer wired into a package broke `swift build` on a Mac.** It is now linked on iOS only, and its import is guarded.
- **`new package --preset full` warned that no target was MainActor-isolated.** With `defaultIsolation` and no `--main-actor-targets`, the only library target now gets it.
- **`new package --main-actor-targets` without `--features defaultIsolation` isolated those targets in Package.swift, but the Makefile, README, and CLAUDE.md treated the package as unisolated** and used `swift build`. The flag now turns on `defaultIsolation`, so the output matches passing both.

**Generated CLIs**
- **A CLI with a hyphenated name such as `my-tool` didn't compile**, and its `--help` didn't show the binary's name. Its own `make check` now passes too.
- **`new cli --dry-run` listed files the real run doesn't write.**

**Generated tooling and docs**
- **The generated CLAUDE.md linked to a workspace CLAUDE.md two folders up**, which a new project doesn't have.
- **Apps without dev tooling were pointed at `make` targets that don't exist.** Their docs now give raw `xcodebuild` commands, and the next steps print `git config core.hooksPath Scripts/git-hooks` instead of `make setup-hooks`.
- **The generated docs described `make check` as lint and format only**, though it also runs the string audit and the icon check when those features are on.
- **The generated pre-commit hook skipped renamed files and broke on paths with spaces.** Staged files were listed with `--diff-filter=ACM`, which leaves a rename out, and handed to the tools through a plain `xargs`, which splits `My Sources/My File.swift` into three paths that do not exist. The hook now lists added, copied, modified, and renamed files NUL-separated and passes them with `xargs -0`. Projects generated earlier keep their old hook. `monolith add gitHooks` writes the new one over it, in its basic form: hand edits and the Core Data reminder are not carried over.

**`monolith add`**
- **`add widget` replaced the app's entitlements**, dropping iCloud and push settings. It now merges the App Group into them.
- **`add widget` built the widget under `com.example.<app>`** unless `--bundle-id` was passed. It now reads the app's bundle ID from the project; `--bundle-id` applies only when the project sets none.
- **`add widget` on a Mac Catalyst app broke the Mac build.** The widget is now embedded in iOS builds only.
- **`add lottie` and `add widget` broke `project.yml` in projects that declare schemes.**
- **`add` took the app's name from the directory**, so a project in a renamed folder got the wrong paths, and `--path .` failed.
- **The `MacWindowConfig.swift` from `add macCatalyst` didn't compile** in an app without `AppConstants.MacWindow`, and drew Swift 6 concurrency warnings.
- **`add devTooling`, `gitHooks`, `claudeMD`, `privacyManifest`, and `macCatalyst` wrote something other than what `new` writes for the same project**; `add gitHooks`, for example, left out a CloudKit app's model reminder.
- **A package with an executable target beside its libraries was detected as a CLI.**
- **An unreadable `Package.swift` was detected as a library package**, so `add` went ahead against a project it could not read. Detection now fails with the read error.

**The CLI**
- **Unknown or malformed input was ignored or replaced by a default**: unknown features, platforms, and project systems, tabs without an icon, malformed `--target-deps` entries, and bad values for `--preset`, `--license`, `list features --type`, `completions`, and the `add` feature. Each now fails with the valid choices, often with a "did you mean", and help and shell completion list them.
- **`--targets A,A`, duplicate external package names, and `--use-packages ':'` crashed Monolith**; they now report an error.
- **Bundle IDs with non-ASCII characters were accepted.**
- **`new app --locales` accepted malformed locale identifiers and duplicates**; it now checks them as `add localization` does.
- **scp-style git URLs (`git@host:owner/repo.git`) were misread in `--external-packages`.**
- **`--load-config` skipped the checks that flags get**, so a bad name, color, bundle ID, platform, or package in a config file went unnoticed until generation. Config files saved by older releases (without `licenseType`, or with removed features) load, or fail with a message that names the key.
- **`--dry-run` wrote the `--save-config` file**, and `--save-config` wrote it even when the run then stopped at a non-empty directory. The file is now written only once generation goes ahead.
- **`--dry-run` didn't mention that the real run would stop at a non-empty directory**; it now warns.
- **Ctrl-C during generation could deadlock**, because the cleanup ran inside the signal handler. Generation now stops at the next file write, removes the partial project, and exits with status 130.
- **The interactive wizard looped forever when input ended**; it now stops with an error. Choosing a preset now pre-marks its features, flags passed to an interactive `new` answer their steps instead of being ignored, and an invalid choice in a list asks again instead of being ignored or replaced by the default.
- **Wizard prompts garbled accented and CJK text**, Delete, Home, End, and Ctrl-arrow inserted stray characters, and an answer pasted ahead could be lost between prompts.
- **The next steps printed before git init**, and suggested setting up hooks that git init had already set up.
- **Help text and listings were wrong in places**: the help for `--resolve`, `--features`, `--use-packages`, `--external-packages`, `--target-deps`, and `--locales`; feature descriptions in the wizard and `list features`; `list features` titling the CLI section and marking as auto-derived features that `--features` accepts; and `doctor` misreporting fastlane's version.
- **Config check failures (such as two persistence layers) printed a usage banner**, and a bad flag value showed the root `monolith <subcommand>` usage instead of the command's own.
- **A child process writing more than 64 KB could hang Monolith.** Output was read only after the child exited, so a child that filled a pipe buffer waited forever. Both streams are now read while the child runs. Failure messages quote stdout when stderr is empty (git explains a failed commit there) and keep the last 20 lines of long output.
- **Failure messages from external tools dropped output that wasn't valid UTF-8**, and didn't say when a signal ended the tool.
- **With output piped, progress lines appeared after the error message.**
- **The xcodegen failure always said "Install with: brew install xcodegen"**, even when xcodegen was installed and had rejected the spec. The hint now appears only when xcodegen is not on `PATH`; otherwise the warning carries xcodegen's own output.
- **A failed step in the initial git setup hid what it skipped.** When `git commit` fails (no git identity, for example), the warning now names the failed command and the ones that did not run, such as `git config core.hooksPath Scripts/git-hooks`, so they can be run by hand.
- **An unreadable output directory counted as empty**, so overwrite protection let generation write into it. It now counts as non-empty: an interactive run asks, a non-interactive one refuses.

## [0.5.0] - 2026-07-27

A bug-fix release. Every generated project type now builds, lints, and tests clean on the first run, without hand-editing the output first.

### Fixed

**Generated apps**
- **A CloudKit Sharing app crashed on launch under its own `make test`.** CloudKit sync was forced on at first launch, which traps in an unsigned build (the generated `make test` builds without code signing), so the test bundle never connected. Sync is now opt-in behind a preference that defaults off, and the privacy manifest declares the matching reason.
- **A CloudKit app without a widget was generated with no entitlements at all.** Entitlements were tied to the widget feature, so CloudKit apps shipped without an iCloud container, the CloudKit service, or a push environment. They now follow the CloudKit features too.
- **Accepting a share on a Core Data app imported nothing.** The invitation was accepted at the CloudKit layer but never brought into the app's shared store, so shared records never showed up locally. SwiftData behavior is unchanged.
- **A Core Data app could not run `make test`:** the test target failed to build because the generated helpers could not see the app's own types. Core Data scaffolds also start with a real round-trip test now instead of an empty suite next to unused helpers.
- **A widget could not read the shared App Group identifier**, forcing adopters to hardcode it on the widget side.
- **Tab bar and Mac menu titles stayed English in localized apps**, while navigation bars localized correctly.
- **A fresh Mac Catalyst app failed its own `make check`**, because generated platform-conditional code did not match the formatter config generated beside it.
- **A fresh multi-locale app failed its own `make check`**, because the string audit treated the untranslated entries it had just created as hard failures. Untranslated strings are now non-fatal warnings; missing locales, placeholder mismatches, and unlocalizable keys still fail.
- **Post-generation next steps pointed Core Data adopters at a file that path never creates.** They now point at the data model.

**Generated packages**
- **A package with a local-path dependency produced a `Package.swift` that would not compile**, which made local paths, the usual way to develop against a sibling framework, unusable.
- **`make build` and `make test` failed on a fresh multi-target package**, because the generated Makefile and docs named a scheme Xcode never creates for that target layout.
- **The generated guide claimed `swift build` and `swift test` work on packages with UI-framework targets.** They fail on a Mac host. The guide now names the targets that can be built that way and shows the per-target form to use for the rest.

**CLI**
- **`new app --dry-run` previewed a different file list than the real run wrote.** The preview now comes from the same plan the generator writes from, and is verified against a real generation.
- **The local-path form of `--external-packages` was documented incorrectly** (`Name=path:../Dir` rather than `Name=../Dir`), and following the docs silently set the dependency path to a literal, unusable string. Wiring a multi-product local package is now documented as well.
- **`--features` help listed fewer than half the available features.** It now lists them all and points at `monolith list features` for the annotated version.

### Tests
- 794 → 828 tests, 71 → 73 suites, zero regressions. New coverage spans CloudKit entitlement and dual-store gating, Core Data test helpers and the persistence demo, share acceptance, App Group wiring into the widget, localized tab and menu titles, the localization audit's warning/failure split, dry-run parity with real generation, local-path package emission, umbrella-scheme selection, and a lint check that runs the formatter against a generated app.

## [0.4.0] - 2026-05-25

### Added
- **`--locales` flag on `new app`**: comma-separated locale codes for the generated `Localizable.xcstrings` catalog. First locale is the source language; non-source entries start at `state: "new"` so the localization audit surfaces them as outstanding work. Default remains `["en"]`.
- **`--category` flag on `new app`**: App Store category (e.g. `public.app-category.productivity`). Defaults to `public.app-category.utilities`. Emitted both as `LSApplicationCategoryType` in the Info.plist and `INFOPLIST_KEY_LSApplicationCategoryType` in build settings, so `xcodebuild archive` doesn't emit the non-fatal "No App Category is set" warning that App Store Connect rejects on upload.
- **3-variant AppIcon skeleton**: `AssetGenerator.generateAppIconContents()` emits three entries: no-appearance (light), `luminosity: dark`, and `luminosity: tinted`. Adopters drop PNGs in instead of restructuring the asset catalog later.
- **`make build-clean` target** in generated Makefiles: runs `xcodebuild clean build` to surface warnings that incremental builds hide.
- **Persistence demo test**: when SwiftData is enabled, `TestGenerator.generateAppTest` emits one `@Test` that exercises `TestContext.makeContainer()` + `TestDataFactory.makeSampleItem(...)` so adopters get a green signal on first `make test` and the helper APIs are referenced.
- **Compact theme via LumiKit 0.9 `UIColor.lmk_dynamic`**: `ColorCodeGenerator` emits one-liner light/dark colors. Generated themes drop ~56% in line count. Requires `DependencyVersion.lumiKit = "0.9.0"`.
- **`InfoPlistGenerator` options**: `urlIdentifier` (emits `CFBundleURLName` in `CFBundleURLTypes`; defaults to `bundleID`) and `applicationCategoryType` (plumbed from `--category`).
- **Standard bundle-metadata keys in Info.plist**: `CFBundleIdentifier`, `CFBundleVersion`, `CFBundleShortVersionString`, `CFBundleName`, `CFBundleDisplayName`, `CFBundleExecutable`, `CFBundleDevelopmentRegion`, `CFBundleInfoDictionaryVersion`, `CFBundlePackageType`, `LSRequiresIPhoneOS`.

### Changed
- **`GENERATE_INFOPLIST_FILE: NO`** in generated XcodeGen YAML when a hand-written `INFOPLIST_FILE` is also declared. Single source of truth instead of opaque merge precedence.
- **`LSApplicationCategoryType` lives in both Info.plist and XcodeGen build settings**: required by `xcodebuild archive` to silence the non-fatal "No App Category" warning that App Store Connect rejects.
- **`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor`** set explicitly alongside the existing `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` so asset wiring is visible in the pbxproj.
- **`MacWindow` consolidated to `AppConstants`**: `SceneDelegate`'s Mac Catalyst block calls `MacWindowConfig.configure(_:)`; `DesignSystemGenerator` no longer re-emits `enum MacWindow`. One canonical home (`AppConstants.MacWindow`) instead of three copies of the same magic numbers.
- **`AppDelegate.modelContainer` non-optional + `fatalError` on init failure**: matches Apple's sample-code pattern; surfaces container-init failures at the load site instead of as misleading "no persistent stores" crashes later. The no-tabs SwiftData scaffold drops the now-dead `guard modelContainer != nil`.
- **`disableTestParallelism` gated on `(coreData || swiftData) && cloudKit`**: plain SwiftData (no CloudKit) has no shared-repository singleton race, so it no longer pays the serial-test-execution cost.
- **`-quiet` on every `xcodebuild` invocation** in generated Makefiles; per-file compile output stays out of recipes, warnings/errors still surface.
- **`ColorDeriver` secondary/tertiary use an analogous palette** (±30° hue shift) instead of triadic (+150°/+210°). Reads as "variants of the primary" instead of jarring complementaries.
- **Generated `Localizable.xcstrings` is multi-locale**: when `--locales` declares more than one, each key emits a `localizations` entry per locale. Source-language entries are `state: "translated"`; non-source entries are `state: "new"`.

### Removed
- **`--features snapKit` and `--features lookin`**: removed per the v0.3 deprecation. The auto-translating shim is gone; the CLI now raises a `ValidationError` listing the migration (`snapKit → --use-packages SnapKit`, `lookin → --use-packages LookinServer`). `AppFeature.deprecatedPackageFeatureNames` replaced by `KnownPackages.removedFeatureAliases`.
- **`monolith add snapKit` and `monolith add lookin`**: removed. Existing projects retrofit via Xcode's native Add Package flow (URLs in `KnownPackages.registry`). `monolith add lottie` is unaffected.
- **`ColorDeriver.DerivedPalette.photoBrowserBackground`**: every derived value was identical, making the dynamic-color wrapper pointless. LumiKit 0.9's `LMKTheme` ships a default; generated themes omit the override.
- **`DesignSystem.MacWindow`**: see Changed; canonical home is `AppConstants.MacWindow`.
- **`DataPublisher.swift` sample singleton from the `combine` feature**: no real consumers, no integration coverage. `generateAsyncService()` (the actual reference template for Task cancellation) stays; the `combine` feature now writes one file.

### Tests
- 774 → 794 tests, 70 → 71 suites, zero regressions. New coverage spans `--locales` / `--category` flag plumbing, the 3-variant AppIcon skeleton, the SwiftData persistence demo test, and multi-locale xcstrings emission.

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
- **`LocalizationAuditGenerator`** — emits `Scripts/localization/audit_strings.py` whenever the `localization` feature is on (both `new app` and `add localization`). Flags missing locales, untranslated state, placeholder-arity mismatches between locales, and the silent-fail Swift `\(...)` interpolation bug (a literal `\(...)` in a catalog key never matches at lookup)
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

[Unreleased]: https://github.com/Luminoid/Monolith/compare/0.5.0...HEAD
[0.5.0]: https://github.com/Luminoid/Monolith/releases/tag/0.5.0
[0.4.0]: https://github.com/Luminoid/Monolith/releases/tag/0.4.0
[0.3.0]: https://github.com/Luminoid/Monolith/releases/tag/0.3.0
[0.2.0]: https://github.com/Luminoid/Monolith/releases/tag/0.2.0
[0.1.0]: https://github.com/Luminoid/Monolith/releases/tag/0.1.0
