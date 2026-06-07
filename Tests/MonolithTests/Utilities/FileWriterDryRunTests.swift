import Foundation
import Testing
@testable import MonolithLib

/// Guards `FileWriter.plannedAppFiles` (which backs the `new app --dry-run`
/// preview) against drift from `AppProjectGenerator.generate`. The dry-run list
/// was hand-maintained and silently fell behind the generators: feature-
/// conditional outputs (Core Data stack + model, CloudKit/widget entitlements,
/// the widget target, app + widget privacy manifests, the app-icon validation
/// script) were generated on disk but never shown in the preview, so a
/// feature-rich `--dry-run` under-reported by ~15 files.
///
/// These tests actually generate a project and assert the planned set equals
/// the real on-disk set, so any future generator that adds a file fails here
/// until `plannedAppFiles` is updated to match.
///
/// Nested under `MonolithIntegrationSuite` so `.serialized` propagates downward
/// and `withTempDir` (which chdirs) cannot race sibling suites.
extension MonolithIntegrationSuite {
    struct FileWriterDryRunTests {
        /// All regular files under `basePath`, as paths relative to it. The
        /// `.xcodeproj` bundle is collapsed to its top-level path to match
        /// `plannedAppFiles`, which lists the bundle as one logical entry
        /// (xcodegen writes the internals). Uses `.xcodeGen` configs in these
        /// tests anyway, so no `.xcodeproj` bundle is produced.
        private func realFiles(under basePath: String) -> Set<String> {
            let baseURL = URL(fileURLWithPath: basePath)
            guard let enumerator = FileManager.default.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: []
            ) else { return [] }

            var result: Set<String> = []
            for case let url as URL in enumerator {
                let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
                guard isRegular else { continue }
                let full = url.standardizedFileURL.path
                let prefix = baseURL.standardizedFileURL.path + "/"
                guard full.hasPrefix(prefix) else { continue }
                result.insert(String(full.dropFirst(prefix.count)))
            }
            return result
        }

        @Test
        func `dry-run plan matches real generation for a feature-rich app`() throws {
            try withTempDir(prefix: "monolith-dryrun-rich") { tempDir in
                let config = AppConfig(
                    name: "RichApp",
                    bundleID: "com.test.rich",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone, .iPad, .macCatalyst],
                    projectSystem: .xcodeGen,
                    tabs: [
                        TabDefinition(name: "Trips", icon: "suitcase.fill"),
                        TabDefinition(name: "Map", icon: "map.fill"),
                    ],
                    primaryColor: "#1E88A8",
                    features: [
                        .lumiKit, .combine, .darkMode, .lottie,
                        .coreData, .cloudKit, .cloudKitSharing,
                        .widget, .notifications, .deepLinks, .spotlight, .deferredLaunchWork,
                        .localization, .privacyManifest, .appIconValidation,
                        .devTooling, .gitHooks, .claudeMD, .licenseChangelog,
                    ],
                    author: "Test",
                    licenseType: .proprietary
                )

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/RichApp"
                let planned = Set(FileWriter.plannedAppFiles(config: config))
                let real = realFiles(under: basePath)

                let missingFromPlan = real.subtracting(planned).sorted()
                let extraInPlan = planned.subtracting(real).sorted()

                #expect(missingFromPlan.isEmpty, "dry-run omits real files: \(missingFromPlan)")
                #expect(extraInPlan.isEmpty, "dry-run lists files that aren't generated: \(extraInPlan)")
            }
        }

        @Test
        func `dry-run plan matches real generation for a minimal app`() throws {
            try withTempDir(prefix: "monolith-dryrun-min") { tempDir in
                let config = AppConfig(
                    name: "MinApp",
                    bundleID: "com.test.min",
                    deploymentTarget: "18.0",
                    platforms: [.iPhone],
                    projectSystem: .xcodeGen,
                    tabs: [],
                    primaryColor: "#007AFF",
                    features: [],
                    author: "Test",
                    licenseType: .proprietary
                )

                try AppProjectGenerator.generate(config: config)

                let basePath = "\(tempDir)/MinApp"
                let planned = Set(FileWriter.plannedAppFiles(config: config))
                let real = realFiles(under: basePath)

                // Minimal config exercises the no-tabs (Features/.gitkeep) and
                // no-persistence (Core/Models/.gitkeep) seed branches.
                #expect(planned.contains("MinApp/Features/.gitkeep"))
                #expect(planned.contains("MinApp/Core/Models/.gitkeep"))
                #expect(real.subtracting(planned).sorted() == [])
                #expect(planned.subtracting(real).sorted() == [])
            }
        }
    }
}
