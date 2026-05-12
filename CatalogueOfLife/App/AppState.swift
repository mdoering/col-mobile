import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private let client: APIClient
    private let defaults: UserDefaults

    var availableReleases: [DatasetRef] = []
    private(set) var latestExtendedKey: Int?
    private(set) var latestBaseKey: Int?
    private(set) var loadReleasesError: APIError?

    /// Numeric key of the user's selected dataset. Persists across launches.
    var selectedDatasetKey: Int {
        didSet { defaults.set(selectedDatasetKey, forKey: Keys.selectedDatasetKey) }
    }

    /// ISO 639-3 code, or nil for "none".
    var preferredVernacularLang: String? {
        didSet {
            if let v = preferredVernacularLang {
                defaults.set(v, forKey: Keys.preferredVernacularLang)
            } else {
                defaults.removeObject(forKey: Keys.preferredVernacularLang)
            }
        }
    }

    var selectedDataset: DatasetRef? {
        availableReleases.first { $0.key == selectedDatasetKey }
    }

    /// True only when the user has selected the latest extended (3LXR) or base (3LR) release.
    /// GBIF's COL checklist tracks identifiers from those two specific releases.
    var gbifAvailable: Bool {
        let k = selectedDatasetKey
        return (latestExtendedKey.map { $0 == k } ?? false)
            || (latestBaseKey.map { $0 == k } ?? false)
    }

    init(client: APIClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        self.selectedDatasetKey = defaults.integer(forKey: Keys.selectedDatasetKey)
        self.preferredVernacularLang = defaults.string(forKey: Keys.preferredVernacularLang)
    }

    /// Load the release list and resolve the current 3LXR / 3LR numeric keys in parallel.
    /// Sorts the list and applies a default selection if none persists.
    func loadReleases() async {
        async let extendedTask: DatasetRef? = try? await client.getDataset("3LXR")
        async let baseTask: DatasetRef? = try? await client.getDataset("3LR")
        do {
            let raw = try await client.listReleases()
            let extended = await extendedTask
            let base = await baseTask

            self.latestExtendedKey = extended?.key
            self.latestBaseKey = base?.key

            // Merge resolved refs into the list (in case /dataset omits them).
            var merged = raw
            for ref in [extended, base].compactMap({ $0 }) where !merged.contains(where: { $0.key == ref.key }) {
                merged.append(ref)
            }

            self.availableReleases = DatasetRef.sortedForPicker(
                merged,
                latestExtendedKey: extended?.key,
                latestBaseKey: base?.key
            )

            // On first launch (or if stored selection has disappeared), default to the latest extended release.
            if !availableReleases.contains(where: { $0.key == selectedDatasetKey }) {
                if let extendedKey = extended?.key {
                    self.selectedDatasetKey = extendedKey
                } else if let baseKey = base?.key {
                    self.selectedDatasetKey = baseKey
                } else if let first = availableReleases.first {
                    self.selectedDatasetKey = first.key
                }
            }
            self.loadReleasesError = nil
        } catch let err as APIError {
            self.loadReleasesError = err
        } catch {
            self.loadReleasesError = .server(status: -1)
        }
    }

    private enum Keys {
        static let selectedDatasetKey = "selectedDatasetKey"
        static let preferredVernacularLang = "preferredVernacularLang"
    }
}
