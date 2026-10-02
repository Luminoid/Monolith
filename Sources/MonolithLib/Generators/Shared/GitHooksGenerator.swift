/// Generates a pre-commit hook that runs SwiftLint + SwiftFormat on staged
/// `.swift` files (added, copied, modified, or renamed; any path, spaces
/// included) and fails when either tool is missing. Optional add-ons (Core
/// Data model audit reminder, custom extra commands) are appended when
/// requested.
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
        # Added, copied, modified, and renamed files, NUL-separated so a path
        # with spaces reaches the tools as one argument.
        staged_swift_files() {
            git diff --cached --name-only -z --diff-filter=ACMR -- '*.swift'
        }

        STAGED_COUNT=$(staged_swift_files | tr -cd '\\0' | wc -c | tr -d ' ')

        if [ "$STAGED_COUNT" -eq 0 ]; then
            exit 0
        fi

        echo "Pre-commit: checking $STAGED_COUNT staged Swift file(s)..."

        # A missing tool fails the hook: a check that is skipped reads as one that passed.
        for tool in swiftlint swiftformat; do
            if ! command -v "$tool" &> /dev/null; then
                echo "error: $tool not found (install: brew install $tool)" >&2
                exit 1
            fi
        done

        # SwiftLint (lint only, no fix)
        staged_swift_files | xargs -0 swiftlint lint --strict --quiet

        # SwiftFormat (check only, no modify)
        staged_swift_files | xargs -0 swiftformat --lint

        echo "Pre-commit: all checks passed."

        """)

        return lines.joined(separator: "\n")
    }
}
