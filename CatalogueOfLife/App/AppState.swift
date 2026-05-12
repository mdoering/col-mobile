import Foundation
import Observation

struct ReleaseChoice: Equatable, Identifiable, Sendable {
    let displayName: String
    let dataset: DatasetRef
    var id: Int { dataset.key }
}

@MainActor
@Observable
final class AppState {
    private let client: APIClient
    private let defaults: UserDefaults

    var availableReleases: [ReleaseChoice] = []
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
        availableReleases.first { $0.dataset.key == selectedDatasetKey }?.dataset
    }

    /// The language code to use for common-name display, falling back to the system
    /// language if the user hasn't set an explicit preference. Returns nil only if
    /// the system language can't be mapped to ISO 639-3.
    var effectiveVernacularLanguage: String? {
        if let stored = preferredVernacularLang { return stored }
        return Locale.current.language.languageCode?.identifier(.alpha3)
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

    private static let pickerSpec: [(alias: String, display: String)] = [
        ("3LXR",    "Latest"),
        ("3LR",     "Latest Base"),
        ("COL2025", "COL 2025"),
        ("COL2024", "COL 2024"),
        ("COL2023", "COL 2023"),
        ("COL2022", "COL 2022"),
        ("COL2021", "COL 2021"),
    ]

    /// Load the 7 named releases in parallel and apply a default selection if none persists.
    func loadReleases() async {
        async let r0 = try? await client.getDataset(Self.pickerSpec[0].alias)
        async let r1 = try? await client.getDataset(Self.pickerSpec[1].alias)
        async let r2 = try? await client.getDataset(Self.pickerSpec[2].alias)
        async let r3 = try? await client.getDataset(Self.pickerSpec[3].alias)
        async let r4 = try? await client.getDataset(Self.pickerSpec[4].alias)
        async let r5 = try? await client.getDataset(Self.pickerSpec[5].alias)
        async let r6 = try? await client.getDataset(Self.pickerSpec[6].alias)

        let resolved: [DatasetRef?] = await [r0, r1, r2, r3, r4, r5, r6]

        let choices: [ReleaseChoice] = zip(Self.pickerSpec, resolved).compactMap { spec, dataset in
            guard let dataset else { return nil }
            return ReleaseChoice(displayName: spec.display, dataset: dataset)
        }

        self.availableReleases = choices
        self.latestExtendedKey = choices.first(where: { $0.displayName == "Latest" })?.dataset.key
        self.latestBaseKey = choices.first(where: { $0.displayName == "Latest Base" })?.dataset.key

        if !choices.contains(where: { $0.dataset.key == selectedDatasetKey }) {
            if let extendedKey = latestExtendedKey {
                self.selectedDatasetKey = extendedKey
            } else if let baseKey = latestBaseKey {
                self.selectedDatasetKey = baseKey
            } else if let first = choices.first {
                self.selectedDatasetKey = first.dataset.key
            }
        }
        self.loadReleasesError = nil
    }

    private enum Keys {
        static let selectedDatasetKey = "selectedDatasetKey"
        static let preferredVernacularLang = "preferredVernacularLang"
    }
}
