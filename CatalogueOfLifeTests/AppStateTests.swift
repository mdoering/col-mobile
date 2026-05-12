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

    private func sampleStub() -> StubAPIClient {
        let stub = StubAPIClient()
        let extended = DatasetRef(key: 100, alias: "COL26.4 XR", title: "Catalogue of Life",
                                   version: "2026-04-15", issued: "2026-04-15", origin: "xrelease", citation: nil)
        let base = DatasetRef(key: 200, alias: "COL26.4", title: "Catalogue of Life",
                               version: "2026-04-15", issued: "2026-04-15", origin: "release", citation: nil)
        let annual = DatasetRef(key: 300, alias: "COL24", title: "Catalogue of Life",
                                 version: "2024-01-01", issued: "2024-01-01", origin: "release", citation: nil)
        stub.datasetByKey["3LXR"] = extended
        stub.datasetByKey["3LR"] = base
        stub.releases = [annual, base, extended]
        return stub
    }

    @Test("Defaults to latest extended release when no prior selection")
    func defaultsToLatestExtended() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.selectedDatasetKey == 100)
        #expect(state.gbifAvailable == true)
        #expect(state.availableReleases.map(\.key) == [100, 200, 300])
    }

    @Test("Selecting the latest base release also enables gbifAvailable")
    func baseReleaseEnablesGBIF() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        state.selectedDatasetKey = 200
        #expect(state.gbifAvailable == true)
    }

    @Test("Selecting an annual release disables gbifAvailable")
    func annualDisablesGBIF() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        state.selectedDatasetKey = 300
        #expect(state.gbifAvailable == false)
    }

    @Test("Honors stored selection if still available")
    func honorsStoredSelection() async {
        let defaults = freshDefaults()
        defaults.set(300, forKey: "selectedDatasetKey")
        let stub = sampleStub()
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.selectedDatasetKey == 300)
        #expect(state.gbifAvailable == false)
    }

    @Test("Resolves alias keys even when /dataset list omits them")
    func mergesResolvedAliases() async {
        let defaults = freshDefaults()
        let stub = sampleStub()
        stub.releases = stub.releases.filter { $0.key != 100 }
        let state = AppState(client: stub, defaults: defaults)
        await state.loadReleases()
        #expect(state.availableReleases.contains(where: { $0.key == 100 }))
        #expect(state.selectedDatasetKey == 100)
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
}
