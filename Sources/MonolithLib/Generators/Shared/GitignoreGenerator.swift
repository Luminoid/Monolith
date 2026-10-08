enum GitignoreGenerator {
    struct Options {
        var projectType: ProjectType = .app
        var hasRSwift: Bool = false
        var hasFastlane: Bool = false
        var appName: String?
        /// A package that ships an executable target commits
        /// `Package.resolved`, like an app or CLI: the tool's dependency
        /// revisions are part of what it ships.
        var hasExecutables: Bool = false
    }

    static func generate(options: Options) -> String {
        var sections: [String] = []

        // Xcode. `*.xcuserstate` catches the per-user UI state file Xcode
        // writes inside `*.xcodeproj/xcuserdata/`; while `xcuserdata/` already
        // matches the directory, the explicit pattern guards against tooling
        // that flattens the directory or re-creates `*.xcuserstate` elsewhere.
        var xcodeLines = [
            "# Xcode",
            "xcuserdata/",
            "*.xcuserstate",
            "DerivedData/",
            "*.hmap",
            "*.ipa",
            "*.dSYM.zip",
            "*.dSYM",
        ]
        if options.projectType == .app {
            xcodeLines.append("timeline.xctimeline")
            xcodeLines.append("playground.xcworkspace")
        }
        if options.projectType == .package {
            xcodeLines.append("*.xcscmblueprint")
        }
        sections.append(xcodeLines.joined(separator: "\n"))

        // Homebrew. `Brewfile.lock.json` is written by `brew bundle` when it
        // installs from `Brewfile`. Whether to commit it is contentious; the
        // generated projects don't (the Brewfile floor pins are the
        // contract, the lockfile is a per-developer artifact).
        sections.append("""
        # Homebrew
        Brewfile.lock.json
        """)

        // Swift Package Manager. `.swiftpm/configuration/` is created by
        // Xcode 16+ for local-package state (per-user IDE config) regardless
        // of project type — ignore it everywhere. `Package.resolved` is
        // gitignored only for libraries (where downstream consumers pin their
        // own); apps, CLIs, and packages with an executable commit it so the
        // same dependency revisions resolve across machines and CI.
        var spmLines = ["# Swift Package Manager", ".build/", "build/", ".swiftpm/"]
        if options.projectType == .package, !options.hasExecutables {
            spmLines.append("Package.resolved")
        }
        sections.append(spmLines.joined(separator: "\n"))

        sections.append("""
        # macOS
        .DS_Store
        """)

        // Editor / IDE artifacts. Non-Xcode editors are common alongside
        // Xcode (SweetPad/VSCode for fast file edits, AppCode for refactors,
        // Cursor). The default scaffold should tolerate them without each
        // adopter re-adding the same lines.
        sections.append("""
        # Editors / IDEs
        .vscode/
        .idea/
        *.iml
        buildServer.json
        """)

        // Coverage + logs. `.profraw` / `.profdata` accumulate from
        // `xcodebuild test -enableCodeCoverage YES`; `*.log` catches
        // build-script and CI artifacts that get dropped at the repo root.
        sections.append("""
        # Coverage / logs
        *.profraw
        *.profdata
        *.log
        """)

        sections.append("""
        # Claude Code
        .claude/settings.local.json
        """)

        // A home for notes, exports, and scratch files that stay on one
        // machine (audit reports, local test data, signing scratch).
        if options.projectType == .app {
            sections.append("""
            # Local-only files
            Local/
            """)
        }

        // R.swift (iOS app only)
        if options.hasRSwift, let appName = options.appName {
            sections.append("""
            # R.swift generated
            \(appName)/Generated/R.generated.swift
            """)
        }

        // Fastlane
        if options.hasFastlane {
            sections.append("""
            # Fastlane
            fastlane/report.xml
            fastlane/Preview.html
            fastlane/screenshots/**/*.png
            fastlane/test_output

            # Bundler
            vendor/bundle/
            """)
        }

        return sections.joined(separator: "\n\n") + "\n"
    }
}
