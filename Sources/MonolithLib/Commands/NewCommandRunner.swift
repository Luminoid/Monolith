import ArgumentParser
import Foundation

/// Shared orchestration for the `new {app,package,cli}` commands. The three
/// commands diverge in flag-parsing and config-building (different config
/// types, different wizard steps), but the post-config path is identical:
/// validate, warn, print the dry-run preview or run the pipeline of
/// overwrite-check, signal-install, generate, git init, package resolve,
/// open in IDE, and the closing summary. Changes to that path land once.
enum NewCommandRunner {
    /// What a command prints once its project is in place.
    struct Summary {
        /// The first line, e.g. "MyApp app created at /path".
        var headline: String
        /// Next steps for this kind of project, after the tooling and hooks steps.
        var steps: [String] = []
    }

    /// The warning for `--features strictConcurrency`, which every project
    /// type accepts and none acts on.
    static let strictConcurrencyWarning =
        "--features strictConcurrency is a no-op at swift-tools-version \(ToolVersion.swift): strict concurrency is already the language default."

    /// Run the post-config pipeline.
    ///
    /// `config` is validated first, with `validateForGeneration()`, so a
    /// config from flags, the wizard, or `--load-config` meets the same rules
    /// before anything is saved, previewed, or written; a failure throws the
    /// config's own error. `warnings` (and the strictConcurrency warning when
    /// `requestsStrictConcurrency`) go to stderr next. A dry run prints the
    /// preview and stops: it saves no config. Otherwise `saveConfigPath`
    /// (`--save-config`) is written before generation.
    ///
    /// `generate` is the per-command call into the matching project
    /// generator; throwing from it aborts the pipeline before git init /
    /// resolve / open run, and the partial output is removed if the directory
    /// didn't pre-exist. A Ctrl-C during `generate` stops it at the next file
    /// write, removes the partial output the same way, and exits 130. An
    /// `IncompleteGenerationError` is the exception: every file was written,
    /// so the output stays for the user to finish. Either way the error
    /// propagates and the command exits non-zero. The Ctrl-C handler is
    /// disarmed as soon as `generate` returns or throws, so an interrupt
    /// during git init, package resolve, or open leaves the finished project
    /// in place.
    ///
    /// `summary` gives the closing headline and steps; it prints last, after
    /// git init, so the hooks step shows only when git init didn't already
    /// set `core.hooksPath`. `printDryRun` is a closure because
    /// `DryRunPlanner.printDryRun` has three concrete overloads (one per
    /// config type) and overload dispatch needs the concrete type at the call
    /// site.
    static func run(
        config: some GeneratableConfig,
        saveConfigPath: String? = nil,
        outputDir: String?,
        force: Bool,
        interactive: Bool,
        dryRun: Bool,
        shouldInitGit: Bool,
        shouldResolve: Bool,
        shouldOpen: Bool,
        hasGitHooks: Bool,
        hasDevTooling: Bool = false,
        requestsStrictConcurrency: Bool = false,
        warnings: [String] = [],
        projectSystem: ProjectSystem,
        printDryRun: () -> Void,
        generate: () throws -> Void,
        summary: (_ basePath: String) -> Summary = { _ in Summary(headline: "Done!") }
    ) throws {
        try config.validateForGeneration()

        for warning in warnings + (requestsStrictConcurrency ? [strictConcurrencyWarning] : []) {
            Console.warn(warning)
        }

        let projectName = config.name
        if dryRun {
            if let saveConfigPath {
                Console.warn("Dry run: the config was not saved to \(saveConfigPath).")
            }
            let target = FileWriter.resolveOutputPath(projectName: projectName, outputDir: outputDir)
            if !force, OverwriteProtection.directoryState(at: target) != .absentOrEmpty {
                Console.warn("'\(target)' is not empty: a real run would \(interactive ? "ask before overwriting it" : "refuse without --force").")
            }
            printDryRun()
            return
        }

        let overwriteResult = try OverwriteProtection.check(
            projectName: projectName,
            outputDir: outputDir,
            force: force,
            interactive: interactive
        )
        try stopIfDeclined(overwriteResult)

        // Saved only once generation is going ahead, so a declined or refused
        // overwrite leaves no config file behind.
        if let saveConfigPath {
            try ConfigFile.save(config.monolithConfig(initGit: shouldInitGit), to: saveConfigPath)
        }

        let basePath = FileWriter.resolveOutputPath(projectName: projectName, outputDir: outputDir)
        // If the directory didn't exist before generation, a Ctrl-C mid-write
        // or a failed generation should remove the partial output. If it
        // existed and we got here via --force, leave it alone to avoid blowing
        // away unrelated content. Only the writes are covered: once `generate`
        // is done the project is complete, and a Ctrl-C during a slow
        // `swift package resolve` must not delete it.
        let preexisting = FileManager.default.fileExists(atPath: basePath)
        if !preexisting {
            SignalHandler.install()
        }

        do {
            defer { SignalHandler.uninstall() }
            try SignalHandler.$guardsWrites.withValue(true) {
                try generate()
                try SignalHandler.throwIfInterrupted()
            }
        } catch let error as IncompleteGenerationError {
            throw error
        } catch is SignalHandler.InterruptedError {
            Console.printError("")
            Console.warn("Interrupted.")
            if !preexisting {
                SignalHandler.removePartialOutput(at: basePath)
            }
            throw ExitCode(130)
        } catch {
            if !preexisting {
                SignalHandler.removePartialOutput(at: basePath)
            }
            throw error
        }

        var hooksConfigured = false
        if shouldInitGit {
            hooksConfigured = GitRunner.initRepository(at: basePath, hasGitHooks: hasGitHooks) && hasGitHooks
        }

        if shouldResolve {
            PackageResolver.resolve(at: basePath, projectSystem: projectSystem)
        }

        if shouldOpen {
            ProjectOpener.open(at: basePath, projectSystem: projectSystem)
        }

        printSummary(summary(basePath), hasDevTooling: hasDevTooling, hasGitHooks: hasGitHooks, hooksConfigured: hooksConfigured)
    }

    /// A declined overwrite prompt ends the command with exit code 1 and a
    /// note on stderr, so a script can tell it from a finished generation.
    static func stopIfDeclined(_ result: OverwriteProtection.Result) throws {
        guard result == .abort else { return }
        Console.warn("Aborted; nothing was written.")
        throw ExitCode(1)
    }

    // MARK: - Summary

    /// The headline, then the next steps when there are any.
    static func printSummary(_ summary: Summary, hasDevTooling: Bool, hasGitHooks: Bool, hooksConfigured: Bool) {
        print()
        print("  \(summary.headline)")
        let steps = nextSteps(summary, hasDevTooling: hasDevTooling, hasGitHooks: hasGitHooks, hooksConfigured: hooksConfigured)
        guard !steps.isEmpty else { return }
        print()
        print("  Next steps:")
        for step in steps {
            print("    \(step)")
        }
    }

    /// `brew bundle` with dev tooling; the hooks step unless git init already
    /// set `core.hooksPath` (`make setup-hooks` with the dev-tooling
    /// Makefile, the git command without it); then the project's own steps.
    static func nextSteps(_ summary: Summary, hasDevTooling: Bool, hasGitHooks: Bool, hooksConfigured: Bool) -> [String] {
        CLIProjectGenerator.nextSteps(hasDevTooling: hasDevTooling, hasGitHooks: hasGitHooks && !hooksConfigured) + summary.steps
    }
}

/// Generation wrote every file, but a required step after the writes failed
/// (xcodegen, in `.xcodeproj` mode). The output is kept so the user can finish
/// by hand; the command still exits non-zero, and git init, package resolve,
/// and open are skipped.
struct IncompleteGenerationError: Error, CustomStringConvertible {
    let description: String
}
