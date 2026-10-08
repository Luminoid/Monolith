/// Generates a pre-commit hook that runs SwiftLint + SwiftFormat on staged
/// `.swift` files (added, copied, modified, or renamed; any path, spaces
/// included) and fails when either tool is missing. Optional CloudKit schema
/// audit reminders (Core Data, SwiftData) are inserted when requested.
enum GitHooksGenerator {
    struct Options {
        /// Print a CloudKit schema-audit reminder when `.xcdatamodel/contents`
        /// or `.xccurrentversion` are staged. For apps whose Core Data stack
        /// syncs through `NSPersistentCloudKitContainer`. Non-blocking — the
        /// commit still proceeds.
        var coreDataAudit: Bool = false
        /// Print a CloudKit schema-audit reminder when a staged change touches
        /// `*/Core/Models/*.swift` or adds or removes an `@Model` line. For
        /// apps whose SwiftData container syncs through CloudKit.
        /// Non-blocking.
        var swiftDataAudit: Bool = false

        static let basic = Self()
        static let withCoreDataAudit = Self(coreDataAudit: true)
        static let withSwiftDataAudit = Self(swiftDataAudit: true)
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
            # Apps using NSPersistentCloudKitContainer need their CloudKit
            # schema audited after any attribute add/rename/remove, and the
            # Production schema deployed before the next App Store / TestFlight
            # build. Non-blocking.
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

        if options.swiftDataAudit {
            lines.append("")
            lines.append("""
            # SwiftData model change → CloudKit schema audit reminder.
            # CloudKit never drops a field: once the schema is in Production,
            # removing or renaming a model or property breaks sync for every
            # installed version. Deploy the Development schema to Production
            # before the next App Store / TestFlight build. Non-blocking.
            # Files under Core/Models/, plus any Swift file whose staged change
            # adds or removes an @Model line. Deletions count.
            SWIFTDATA_STAGED=$( {
                git diff --cached --name-only --diff-filter=ACMRD -- '*/Core/Models/*.swift'
                git diff --cached --name-only --diff-filter=ACMRD -G'@Model' -- '*.swift'
            } | sort -u)
            if [ -n "$SWIFTDATA_STAGED" ]; then
                echo ""
                echo "⚠  SwiftData model change detected:"
                echo "$SWIFTDATA_STAGED" | sed 's/^/    /'
                echo ""
                echo "    Before release, verify:"
                echo "      1. No model or property removed or renamed once the schema is in Production"
                echo "      2. New properties are optional or have a default value"
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
