import Testing
@testable import CatalogueOfLife

@Suite("SourcesViewModel")
@MainActor
struct SourcesViewModelTests {
    private func sample() -> [Source] {
        [
            Source(key: 1, title: "World Plants", alias: "WP", citation: nil, logoURL: nil,
                   license: nil, version: nil, issued: nil, taxonomicScope: "Plants", geographicScope: nil,
                   description: nil, websiteURL: nil, doi: nil, publisher: nil, merged: false),
            Source(key: 2, title: "World Birds", alias: "WB", citation: nil, logoURL: nil,
                   license: nil, version: nil, issued: nil, taxonomicScope: "Birds", geographicScope: nil,
                   description: nil, websiteURL: nil, doi: nil, publisher: nil, merged: false),
        ]
    }

    @Test("Loads sources and reports loaded state")
    func loadsList() async {
        let stub = StubAPIClient()
        stub.sources[9837] = sample()
        let vm = SourcesViewModel(client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(s) = vm.state { #expect(s.count == 2) }
        else { Issue.record("Expected .loaded; got \(vm.state)") }
    }

    @Test("filtered() narrows by case-insensitive title substring")
    func filtersByTitle() async {
        let stub = StubAPIClient()
        stub.sources[9837] = sample()
        let vm = SourcesViewModel(client: stub, getDatasetKey: { 9837 })
        await vm.load()
        vm.query = "plant"
        #expect(vm.filtered().map(\.key) == [1])
    }

    @Test("filtered() narrows by alias substring")
    func filtersByAlias() async {
        let stub = StubAPIClient()
        stub.sources[9837] = sample()
        let vm = SourcesViewModel(client: stub, getDatasetKey: { 9837 })
        await vm.load()
        vm.query = "WB"
        #expect(vm.filtered().map(\.key) == [2])
    }
}
