import Foundation
import Observation

struct ReleaseChoice: Equatable, Identifiable, Sendable {
    let displayName: String
    let dataset: DatasetRef
    var id: Int { dataset.key }
}

/// Carries a "search descendants of this taxon at this rank" request from a
/// taxon detail view across to the Search tab. `label` is the parent taxon's
/// scientific name, shown as a scope chip in the search filter bar.
struct TaxonSearchScope: Equatable, Sendable {
    let taxonId: String
    let label: String
    let rank: Rank
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

    /// User's email, used as the reply-to address for feedback submissions. nil = unset.
    var userEmail: String? {
        didSet {
            if let v = userEmail, !v.isEmpty {
                defaults.set(v, forKey: Keys.userEmail)
            } else {
                defaults.removeObject(forKey: Keys.userEmail)
            }
        }
    }

    /// GBIF map tile style — the raw `style` query value sent to the density tile
    /// endpoint (e.g. `iNaturalist.poly`). One of the `value`s in
    /// `GBIFEndpoints.availableMapTileStyles`.
    var gbifMapStyle: String {
        didSet { defaults.set(gbifMapStyle, forKey: Keys.gbifMapStyle) }
    }

    /// Which name field the search tab is matching against. Persisted globally
    /// so the user's last-used mode is restored on relaunch.
    var searchContent: SearchContent {
        didSet { defaults.set(searchContent.rawValue, forKey: Keys.searchContent) }
    }

    /// Active tab index. Bindable from RootTabView's TabView selection.
    var selectedTabIndex: Int = 0

    /// Pending request to apply a group filter when the search tab opens.
    /// SearchView clears it after applying.
    var pendingSearchGroup: String?

    /// Pending request to scope the search to descendants of a taxon at a given rank.
    /// Set when the user follows a "search descendants" link from a taxon detail
    /// (e.g. tapping "Genera" in the Descendants summary).
    var pendingSearchScope: TaxonSearchScope?

    var hasValidUserEmail: Bool {
        guard let e = userEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty else { return false }
        return Self.isValidEmail(e)
    }

    /// Validate against a pragmatic email regex: one or more allowed local-part chars,
    /// `@`, a domain with at least one dot, and a 2+ letter TLD. Trims whitespace.
    nonisolated static func isValidEmail(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
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

    init(client: APIClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        self.selectedDatasetKey = defaults.integer(forKey: Keys.selectedDatasetKey)
        self.preferredVernacularLang = defaults.string(forKey: Keys.preferredVernacularLang)
        self.userEmail = defaults.string(forKey: Keys.userEmail)
        let validStyleValues = Set(GBIFEndpoints.availableMapTileStyles.map(\.value))
        let storedStyle = defaults.string(forKey: Keys.gbifMapStyle)
        self.gbifMapStyle = (storedStyle.map { validStyleValues.contains($0) ? $0 : nil } ?? nil)
            ?? GBIFEndpoints.defaultMapTileStyle
        self.searchContent = defaults.string(forKey: Keys.searchContent)
            .flatMap(SearchContent.init(rawValue:)) ?? .scientific
    }

    private static let pickerSpec: [(alias: String, display: String)] = [
        ("3LXR",    "Latest Extended"),
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
        self.latestExtendedKey = choices.first(where: { $0.displayName == "Latest Extended" })?.dataset.key
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
        static let userEmail = "userEmail"
        static let gbifMapStyle = "gbifMapStyle"
        static let searchContent = "searchContent"
    }
}
