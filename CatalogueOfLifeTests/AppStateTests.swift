import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("AppState")
@MainActor
struct AppStateTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "AppStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Populate stub with extended + base + one annual release.
    /// Keys used: 100 (3LXR), 200 (3LR), 300 (COL2024).
    private func sampleStub() -> StubAPIClient {
        let stub = StubAPIClient()
        let extended = DatasetRef(key: 100, alias: "COL26.4 XR", title: "Catalogue of Life",
                                   version: "2026-04-15", issued: "2026-04-15", origin: "xrelease", citation: nil,
                                   doi: nil, license: nil, publisher: nil)
        let base = DatasetRef(key: 200, alias: "COL26.4", title: "Catalogue of Life",
                               version: "2026-04-15", issued: "2026-04-15", origin: "release", citation: nil,
                               doi: nil, license: nil, publisher: nil)
        let annual = DatasetRef(key: 300, alias: "COL24", title: "Catalogue of Life",
                                 version: "2024-01-01", issued: "2024-01-01", origin: "release", citation: nil,
                                 doi: nil, license: nil, publisher: nil)
        stub.datasetByKey["3LXR"]    = extended
        stub.datasetByKey["3LR"]     = base
        stub.datasetByKey["COL2024"] = annual
        // COL2025, COL2023, COL2022, COL2021 are intentionally absent — they will be filtered out.
        return stub
    }

    @Test("Defaults to latest extended release when no prior selection")
    func defaultsToLatestExtended() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.selectedDatasetKey == 100)
        // Resolved order: 3LXR (100), 3LR (200), COL2024 (300); others absent.
        #expect(state.availableReleases.map(\.dataset.key) == [100, 200, 300])
        #expect(state.availableReleases.map(\.displayName) == ["Latest Extended", "Latest Base", "COL 2024"])
    }

    @Test("Honors stored selection if still available")
    func honorsStoredSelection() async {
        let defaults = freshDefaults()
        defaults.set(300, forKey: "selectedDatasetKey")
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.selectedDatasetKey == 300)
    }

    @Test("effectiveVernacularLanguage falls back to system locale when unset")
    func effectiveVernacularSystemFallback() {
        let defaults = freshDefaults()
        let state = AppState(client: StubAPIClient(), defaults: defaults)
        // No explicit preference set:
        #expect(state.preferredVernacularLang == nil)
        // System fallback. Locale on iOS simulator defaults to en_US, so we expect "eng" (or whatever the runner reports).
        let systemAlpha3 = Locale.current.language.languageCode?.identifier(.alpha3)
        #expect(state.effectiveVernacularLanguage == systemAlpha3)
    }

    @Test("effectiveVernacularLanguage uses explicit preference when set")
    func effectiveVernacularExplicitPreference() {
        let defaults = freshDefaults()
        let state = AppState(client: StubAPIClient(), defaults: defaults)
        state.preferredVernacularLang = "deu"
        #expect(state.effectiveVernacularLanguage == "deu")
    }

    @Test("Vernacular preference round-trips through UserDefaults")
    func vernacularPersists() {
        let defaults = freshDefaults()
        let state = AppState(client: StubAPIClient(), defaults: defaults)
        state.preferredVernacularLang = "deu"
        #expect(defaults.string(forKey: "preferredVernacularLang") == "deu")
        state.preferredVernacularLang = nil
        #expect(defaults.string(forKey: "preferredVernacularLang") == nil)
    }

    @Test("gbifHexPerTile defaults to 64, clamps to 32…256, and persists")
    func gbifHexPerTilePersistsAndClamps() {
        let defaults = freshDefaults()
        let state = AppState(client: StubAPIClient(), defaults: defaults)
        #expect(state.gbifHexPerTile == 64)
        state.gbifHexPerTile = 128
        #expect(defaults.object(forKey: "gbifHexPerTile") as? Int == 128)
        // Out-of-range values stored in defaults are clamped on next launch.
        defaults.set(500, forKey: "gbifHexPerTile")
        let reloadedHigh = AppState(client: StubAPIClient(), defaults: defaults)
        #expect(reloadedHigh.gbifHexPerTile == 256)
        defaults.set(4, forKey: "gbifHexPerTile")
        let reloadedLow = AppState(client: StubAPIClient(), defaults: defaults)
        #expect(reloadedLow.gbifHexPerTile == 32)
    }

    @Test("searchContent defaults to scientific and round-trips through UserDefaults")
    func searchContentPersists() {
        let defaults = freshDefaults()
        let state = AppState(client: StubAPIClient(), defaults: defaults)
        #expect(state.searchContent == .scientific)
        state.searchContent = .vernacular
        #expect(defaults.string(forKey: "searchContent") == "vernacular")
        // Re-instantiate AppState against the same defaults: stored value wins.
        let reloaded = AppState(client: StubAPIClient(), defaults: defaults)
        #expect(reloaded.searchContent == .vernacular)
    }
}
