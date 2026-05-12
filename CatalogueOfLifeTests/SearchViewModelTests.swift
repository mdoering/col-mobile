import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

    private func make() -> (SearchViewModel, StubAPIClient) {
        let stub = StubAPIClient()
        let vm = SearchViewModel(client: stub, getDatasetKey: { 9837 })
        vm.debounceMillis = 10
        return (vm, stub)
    }

    @Test("Empty query stays idle")
    func emptyQueryIdle() async {
        let (vm, _) = make()
        vm.query = "   "
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(vm.state == .idle)
    }

    @Test("Loads results after debounce")
    func loadsResults() async {
        let (vm, stub) = make()
        let hit = SearchHit(id: "1", scientificName: "Felis catus", authorship: "L., 1758",
                            rank: .species, status: .accepted, acceptedId: nil, group: nil)
        stub.searchResults["felis"] = [hit]
        vm.query = "felis"
        try? await Task.sleep(nanoseconds: 100_000_000)
        if case let .loaded(hits) = vm.state {
            #expect(hits.first?.id == "1")
        } else {
            Issue.record("Expected .loaded but got \(vm.state)")
        }
    }

    @Test("Rapid typing only fires the last query")
    func debounceDropsIntermediate() async {
        let (vm, stub) = make()
        stub.searchResults["fel"] = []
        stub.searchResults["feli"] = []
        stub.searchResults["felis"] = [
            SearchHit(id: "1", scientificName: "Felis", authorship: nil, rank: .genus,
                      status: .accepted, acceptedId: nil, group: nil)
        ]
        vm.query = "fel"
        vm.query = "feli"
        vm.query = "felis"
        try? await Task.sleep(nanoseconds: 100_000_000)
        if case let .loaded(hits) = vm.state {
            #expect(hits.first?.scientificName == "Felis")
        } else {
            Issue.record("Expected .loaded but got \(vm.state)")
        }
    }

    @Test("API error surfaces as .failed")
    func errorSurfaces() async {
        let (vm, stub) = make()
        stub.error = .server(status: 500)
        vm.query = "felis"
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(vm.state == .failed(.server(status: 500)))
    }
}
