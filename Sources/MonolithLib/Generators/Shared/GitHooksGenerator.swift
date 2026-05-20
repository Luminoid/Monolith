/// Generates a pre-commit hook that runs SwiftLint + SwiftFormat on staged
/// `.swift` files. Optional add-ons (Core Data model audit reminder, custom
/// extra commands) are appended when requested.
enum GitHooksGenerator {
    struct Options {
        /// Print a CloudKit schema-audit reminder when `.xcdatamodel/contents`
        /// or `.xccurrentversion` are staged. Recommended for any app whose
        /// persistence layer syncs through CloudKit (NSPersistentCloudKitContainer
        /// or SwiftData with `cloudKitDatabase`). Non-blocking — the commit
        /// still proceeds.
        var coreDataAudit: Bool = false

        static let basic = Self()
        static let withCoreDataAudit = Self(coreDataAudit: true)
    }

    static func generatePreCommitHook(options: Options = .basic) -> String {
        var lines: [String] = []
        lines.append("""
        #!/bin/bash
        #
        # Pre-commit hook — runs SwiftLint + SwiftFormat on staged .swift files.
        # Installed via: make setup-hooks
        #
        # To bypass (emergency): git commit --no-verify

        set -euo pipefail
        """)

        if options.coreDataAudit {
            lines.append("")
            lines.append("""
            # Core Data model change → CloudKit schema audit reminder.
            # Apps using NSPersistentCloudKitContainer (or SwiftData with
            # cloudKitDatabase) need their CloudKit schema audited after any
            # attribute add/rename/remove, and the Production schema deployed
            # before the next App Store / TestFlight build. Non-blocking.
            MODEL_STAGED=$(git diff --cached --name-only --diff-filter=ACMR -- '*.xcdatamodel/contents' '*.xcdatamodeld/.xccurrentversion')
            if [ -n "$MODEL_STAGED" ]; then
                echo ""
                echo "⚠  Core Data model change detected:"
                echo "$MODEL_STAGED" | sed 's/^/    /'
                echo ""
                echo "    Before release, verify:"
                echo "      1. Model version bumped + .xccurrentversion updated"
                echo "      2. CloudKit schema audited against Development export"
                echo "      3. CloudKit Production schema deployed via Dashboard"
                echo ""
            fi
            """)
        }

        lines.append("")
        lines.append("""
        STAGED=$(git diff --cached --name-only --diff-filter=ACM -- '*.swift')

        if [ -z "$STAGED" ]; then
            exit 0
        fi

        echo "Pre-commit: checking $(echo "$STAGED" | wc -l | tr -d ' ') staged Swift file(s)..."

        # SwiftLint (lint only, no fix)
        if command -v swiftlint &> /dev/null; then
            echo "$STAGED" | xargs swiftlint lint --strict --quiet
        else
            echo "warning: swiftlint not found, skipping lint (install: brew install swiftlint)"
        fi

        # SwiftFormat (check only, no modify)
        if command -v swiftformat &> /dev/null; then
            echo "$STAGED" | xargs swiftformat --lint
        else
            echo "warning: swiftformat not found, skipping format check (install: brew install swiftformat)"
        fi

        echo "Pre-commit: all checks passed."

        """)

        return lines.joined(separator: "\n")
    }
}
