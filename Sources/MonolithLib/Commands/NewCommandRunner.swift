import Foundation

/// Shared orchestration for the `new {app,package,cli}` commands. The three
/// commands diverge in flag-parsing and config-building (different config
/// types, different wizard steps, different deprecation shims), but the
/// post-config path is identical: print dry-run summary or actually run the
/// pipeline of overwrite-check → signal-install → generate → git init →
/// package resolve → open in IDE.
///
/// The three commands previously inlined this block. When the
/// `PackageResolver.resolve` signature changed to take `projectSystem:`, the
/// edit had to be applied to all three commands manually — that's the smell
/// this runner is here to fix. Future changes to the post-config path land
/// once.
enum NewCommandRunner {
    /// Run the post-config pipeline. `projectName` and `hasGitHooks` come from
    /// the resolved config (different concrete types per command). `generate`
    /// is the per-command call into the matching project generator; throwing
    /// from it aborts the pipeline before git init / resolve / open run, and
    /// the signal handler's cleanup removes the partial output if the
    /// directory didn't pre-exist. `printDryRun` is also a closure because
    /// `FileWriter.printDryRun` has three concrete overloads (one per config
    /// type) and overload dispatch needs the concrete type at the call site.
    static func run(
        projectName: String,
        outputDir: String?,
        force: Bool,
        noInteractive: Bool,
        dryRun: Bool,
        shouldInitGit: Bool,
        shouldResolve: Bool,
        shouldOpen: Bool,
        hasGitHooks: Bool,
        projectSystem: ProjectSystem,
        printDryRun: () -> Void,
        generate: () throws -> Void
    ) throws {
        if dryRun {
            printDryRun()
            return
        }

        let overwriteResult = OverwriteProtection.check(
            projectName: projectName,
            outputDir: outputDir,
            force: force,
            interactive: !noInteractive
        )
        if overwriteResult == .abort { return }

        let basePath = FileWriter.resolveOutputPath(projectName: projectName, outputDir: outputDir)
        // If the directory didn't exist before generation, a Ctrl-C mid-write
        // should remove the partial output. If it existed and we got here via
        // --force, leave it alone to avoid blowing away unrelated content.
        let preexisting = FileManager.default.fileExists(atPath: basePath)
        if !preexisting {
            SignalHandler.install(cleanup: { SignalHandler.removePartialOutput(at: basePath) })
        }

        try generate()

        if shouldInitGit {
            FileWriter.gitInit(at: basePath, hasGitHooks: hasGitHooks)
        }

        if shouldResolve {
            PackageResolver.resolve(at: basePath, projectSystem: projectSystem)
        }

        if shouldOpen {
            ProjectOpener.open(at: basePath, projectSystem: projectSystem)
        }
    }
}
