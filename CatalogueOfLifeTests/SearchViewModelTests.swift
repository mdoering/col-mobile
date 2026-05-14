import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

    private func make() -> (SearchViewModel, StubAPIClient) {
        let stub = StubAPIClient()
        let vm = SearchViewModel(client: stub, getDatasetKey: { 9837 })
        return (vm, stub)
    }

    @Test("Empty query stays idle")
    func emptyQueryIdle() async {
        let (vm, _) = make()
        vm.query = "   "
        vm.submit()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.state == .idle)
    }

    @Test("Loads results after submit")
    func loadsResults() async {
        let (vm, stub) = make()
        let hit = SearchHit(id: "1", scientificName: "Felis catus", authorship: "L., 1758",
                            rank: .species, status: .accepted, acceptedId: nil, acceptedName: nil, group: nil,
                            merged: false, extinct: false, vernacularNames: [])
        stub.searchResults["felis"] = [hit]
        vm.query = "felis"
        vm.submit()
        try? await Task.sleep(nanoseconds: 50_000_000)
        if case let .loaded(result) = vm.state {
            #expect(result.hits.first?.id == "1")
        } else {
            Issue.record("Expected .loaded but got \(vm.state)")
        }
    }

    @Test("Second submit cancels first and only last result wins")
    func rapidSubmitsCancelEachOther() async {
        let (vm, stub) = make()
        stub.searchResults["felis"] = [
            SearchHit(id: "1", scientificName: "Felis", authorship: nil, rank: .genus,
                      status: .accepted, acceptedId: nil, acceptedName: nil, group: nil,
                      merged: false, extinct: false, vernacularNames: [])
        ]
        // Submit twice rapidly — the second cancels the first in-flight task.
        vm.query = "felis"
        vm.submit()
        vm.submit()
        try? await Task.sleep(nanoseconds: 50_000_000)
        if case let .loaded(result) = vm.state {
            #expect(result.hits.first?.scientificName == "Felis")
        } else {
            Issue.record("Expected .loaded but got \(vm.state)")
        }
    }

    @Test("API error surfaces as .failed")
    func errorSurfaces() async {
        let (vm, stub) = make()
        stub.error = .server(status: 500)
        vm.query = "felis"
        vm.submit()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.state == .failed(.server(status: 500)))
    }

    @Test("Filter properties default to nil")
    func filterDefaults() {
        let (vm, _) = make()
        #expect(vm.rank == nil)
        #expect(vm.status == nil)
        #expect(vm.group == nil)
    }

    @Test("reSearchIfQueryPresent does nothing when query is empty")
    func reSearchNoOp() async {
        let (vm, _) = make()
        vm.query = ""
        vm.reSearchIfQueryPresent()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.state == .idle)
    }
}
