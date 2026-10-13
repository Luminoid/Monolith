enum PackageSourceGenerator {
    /// Generate a placeholder source file for a target.
    ///
    /// `externalDeps` lists external (registry- or `--external-packages`-declared)
    /// dependencies the target has wired in Package.swift. `internalLibDeps`
    /// lists internal-target deps that resolve in the same package. Both get
    /// surfaced as `import` lines (merged + sorted) so the deps wired in
    /// Package.swift aren't dead weight in the source — if the dep is removed
    /// in Package.swift, the file fails to compile, matching the loud-failure
    /// property the executable/test-helper paths already provide.
    ///
    /// Surfacing internal deps closes a gap: a `MultiLibUI` target that depends
    /// on `MultiLibCore` + `MultiLibAdapters` + `LumiKitUI` once imported only
    /// `LumiKitUI` (the external dep), so the two sibling-target deps were
    /// silently invisible in the source.
    static func generateSource(
        targetName: String,
        externalDeps: [String] = [],
        internalLibDeps: [String] = []
    ) -> String {
        // A registry product with a platform condition (LookinServer is
        // iOS-only) is linked only on those platforms, so its import is
        // guarded: `swift build` on a Mac host must not see it.
        let conditional = Set(externalDeps.filter { isPlatformConditional($0) })
        let plainImports = (externalDeps.filter { !conditional.contains($0) } + internalLibDeps)
            .sorted()
            .map { "import \($0)" }
        let guardedImports = conditional.sorted().map { dep in
            "#if canImport(\(dep))\n    import \(dep)\n#endif"
        }
        let importBlock = (plainImports + guardedImports).joined(separator: "\n")
        let declaration = """
        /// \(targetName) module placeholder. Add real public types here.
        public enum \(targetName) {}

        """
        return importBlock.isEmpty ? declaration : importBlock + "\n\n" + declaration
    }

    /// Whether `product` comes from a registry package that is linked only on
    /// some platforms (`condition: .when(platforms:)` in Package.swift).
    static func isPlatformConditional(_ product: String) -> Bool {
        guard let platforms = KnownPackages.entryOwning(product: product)?.platforms else { return false }
        return !platforms.isEmpty
    }

    /// Generate the placeholder for an `--test-helper-targets` library — a
    /// test-helper sibling (typically `<Name>Testing`) consumed by adopter
    /// test targets. The stub uses Swift Testing (the test framework every
    /// generated project uses) and seeds a public namespace so adopters see
    /// the intended pattern without grep-archaeology. XCTest interop is
    /// opt-in: adopters add `import XCTest` to the source and `swift test`
    /// links the framework automatically.
    ///
    /// `internalLibDeps` lists internal-target deps that resolve in the same
    /// package — surfaced as `import <Lib>` lines so the wired-up deps in
    /// Package.swift aren't dead weight in the source.
    static func generateTestHelper(targetName: String, internalLibDeps: [String] = []) -> String {
        let typeName = targetName.upperCamelCased
        // Sort the FULL import list (not just the tail) so output matches
        // SwiftFormat's `sortImports` rule — which the generated .swiftformat
        // opts in to. Without this, `make check` fails on the first run.
        let imports = (["Testing"] + internalLibDeps).sorted().map { "import \($0)" }

        return """
        \(imports.joined(separator: "\n"))

        /// Shared test helpers consumed by adopter test targets.
        ///
        /// Add expectations, fixtures, and factories here so downstream tests
        /// can `import \(targetName)` and reuse them. For XCTest interop, add
        /// `import XCTest` to this file (the toolchain links XCTest on demand).
        public enum \(typeName) {}

        """
    }

    /// Generate the ArgumentParser stub for an executable sibling target (declared
    /// via `--targets name:exec`). One subcommand to make the pattern obvious;
    /// adopters extend by adding more types to `subcommands:`.
    ///
    /// `internalLibDeps` lists the executable's library-target deps that resolve
    /// to internal targets in the same package — those get `import` lines so the
    /// generated stub actually exercises the dep wired up in Package.swift
    /// (otherwise the dep is dead weight, and adopters wondering "why does this
    /// executable depend on the lib?" have no breadcrumb).
    static func generateExecutable(targetName: String, internalLibDeps: [String] = []) -> String {
        let typeName = targetName.upperCamelCased
        // Sort the FULL import list (see generateTestHelper for the same fix).
        let imports = (["ArgumentParser"] + internalLibDeps).sorted().map { "import \($0)" }
        // `defaultSubcommand` makes a bare `<tool>` run `Run` instead of
        // printing help, as its abstract promises.
        let configuration = ArgumentParserStub.configuration(
            commandName: targetName,
            abstract: "\(targetName) command-line tool.",
            subcommands: ["Run"],
            defaultSubcommand: "Run"
        )
        let runConfiguration = ArgumentParserStub.configuration(
            commandName: "run",
            abstract: "Default subcommand. Replace with real commands.",
            includeVersion: false
        )

        return """
        \(imports.joined(separator: "\n"))

        @main
        struct \(typeName): ParsableCommand {
        \(configuration)
        }

        struct Run: ParsableCommand {
        \(runConfiguration)

            func run() throws {
                print("Hello from \(targetName)!")
            }
        }

        """
    }
}
