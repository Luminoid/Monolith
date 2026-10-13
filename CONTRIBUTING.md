# Contributing to Monolith

Thanks for your interest. Monolith is a small, focused codebase; most contributions land cleanly without ceremony.

## Reporting bugs

Open an issue with:

- The command you ran (`monolith new app --name X --features ...`).
- Expected vs actual output. For generated-file bugs, include the path of the offending file and a minimal diff.
- `monolith doctor` output if the issue involves toolchain detection.
- macOS + Xcode + Swift versions.

For reproducible generator bugs, `monolith new ... --no-interactive` plus the `--save-config` JSON is the most useful repro.

## Requesting a feature

Before opening an issue, check the existing feature list (`monolith list features --type app|package|cli`). A new feature is usually one of:

- A new `AppFeature` / `PackageFeature` / `CLIFeature` flag (e.g., adding HealthKit scaffolding).
- A retrofit path for an existing feature (i.e., adding it to `AddableFeature` so `monolith add` can apply it to existing projects).
- A new generator in `Generators/Shared/` (e.g., a build-phase script).

Open a discussion or an issue describing the intent before writing a large PR: generator design decisions are easier to align on early.

## Development setup

```bash
git clone https://github.com/Luminoid/Monolith.git
cd Monolith
brew bundle           # SwiftLint, SwiftFormat
brew install xcodegen # For the app integration tests (they're skipped without it)
make setup-hooks      # Pre-commit lint + format
swift build
swift test
```

The lint tests that run SwiftLint and SwiftFormat over generated projects are skipped when either tool is missing, so install both (via `brew bundle`) for a full run.

## Architecture orientation

Monolith's source is a library + thin executable. Useful entry points:

- `Sources/MonolithLib/Monolith.swift`: `@main` `ParsableCommand` dispatch.
- `Sources/MonolithLib/Commands/`: one file per `monolith <subcommand>`, plus the pieces the `new` commands share (`NewCommandOptions`, `NewCommandWizard`, `NewCommandRunner`) and the `add` planning (`AddFeatureHandlers`, `AddPlan`).
- `Sources/MonolithLib/Config/`: config structs and their validation, `Feature` enums, `Preset`, `LicenseType`, `ConfigFile` (save/load JSON), `ExternalPackage` and the `KnownPackages` registry.
- `Sources/MonolithLib/Generators/{App,Package,CLI,Shared}/`: pure-function `(Config) -> String` generators. No side effects; `FileWriter` does I/O at the call sites.
- `Sources/MonolithLib/Utilities/`: `ColorDeriver`, `DryRunPlanner` (the `--dry-run` file lists), `ProjectState` and `ProjectYamlEditor` (what `monolith add` reads and edits), `EntitlementsMerger`, `ShellRunner`, `ToolChecker`, `OverwriteProtection`.
- `Tests/MonolithTests/`: mirrors source layout; integration tests use a serial `MonolithIntegrationSuite` parent so concurrent `currentDirectoryPath` mutations can't race.

The [integration test coverage matrix](README.md#integration-test-coverage) lists every feature → test mapping. When you add a feature, add it to that table in the same PR.

## Adding a feature

1. Extend the appropriate enum in `Sources/MonolithLib/Config/Feature.swift` (and `AddableFeature.swift` if it's retrofit-safe).
2. Read existing related generators for shape; `WidgetExtensionGenerator` and `CoreDataGenerator` are good references. If the feature writes a new file, add it to `DryRunPlanner` too: the dry-run parity tests compare the plan with a real run.
3. Add **one** focused integration test in the appropriate suite (per-feature) and update the coverage matrix in `README.md`.
4. If the feature interacts with another feature in a way that produces output different from either alone, add a dedicated combination test under "Combinations with distinct output".
5. If the feature has a retrofit path, add a case to `AddableFeature` and a plan in `AddFeatureHandlers.plan(_:state:options:)` (`Sources/MonolithLib/Commands/AddFeatureHandlers.swift`). The plan should write what `monolith new` writes for the same project; read what you need from `ProjectState`.

## Code style

- SwiftLint and SwiftFormat run via `make check` and the pre-commit hook. There is no hosted CI yet, so run them locally before pushing.
- Force-unwrap (`!`) and force-cast (`as!`) are warnings; don't ship them in `Sources/MonolithLib/`.
- Trailing commas mandatory on collection literals.
- Generators that emit Swift code should themselves follow the same Swift 6.2 conventions they emit.

## Pull requests

- Branch from `main`.
- Run `swift test && make check` before pushing.
- Keep PRs focused: one bug or feature per PR. Refactors land separately.
- The PR description should answer: what changed, why, and how to verify (the test that covers it).

## License

By contributing, you agree your contribution is licensed under the [Apache License 2.0](LICENSE).
