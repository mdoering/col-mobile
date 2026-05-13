import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("TaxonDetailViewModel")
@MainActor
struct TaxonDetailViewModelTests {

    private func sampleInfo(id: String = "T1") -> TaxonInfo {
        TaxonInfo(
            taxonId: id,
            scientificName: "Felis catus",
            authorship: "L., 1758",
            rank: .species,
            status: .accepted,
            group: nil,
            classification: [
                ClassificationItem(id: "K", name: "Animalia", rank: .kingdom),
                ClassificationItem(id: "G", name: "Felis", rank: .genus)
            ],
            synonymyGroups: [],
            vernacularNames: [
                VernacularName(id: "v0", name: "House cat", language: "eng", country: nil, area: nil),
                VernacularName(id: "v1", name: "Hauskatze", language: "deu", country: nil, area: nil)
            ],
            publishedInCitation: nil,
            sourceDatasetKey: nil,
            nameRelations: [],
            merged: false,
            extinct: false,
            remarks: nil,
            etymology: nil,
            typeMaterials: []
        )
    }

    @Test("Loads taxon info successfully")
    func loadsSuccess() async {
        let stub = StubAPIClient()
        stub.taxonInfo["T1"] = sampleInfo()
        let vm = TaxonDetailViewModel(taxonId: "T1", client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(info) = vm.state {
            #expect(info.scientificName == "Felis catus")
        } else {
            Issue.record("Expected .loaded")
        }
    }

    @Test("Surfaces notFound when API returns it")
    func notFound() async {
        let stub = StubAPIClient()
        let vm = TaxonDetailViewModel(taxonId: "missing", client: stub, getDatasetKey: { 9837 })
        await vm.load()
        #expect(vm.state == .failed(.notFound))
    }

    @Test("preferredVernacular returns the language match")
    func preferredVernacularMatches() {
        let info = sampleInfo()
        #expect(info.preferredVernacular(language: "deu")?.name == "Hauskatze")
        #expect(info.preferredVernacular(language: "fra") == nil)
        #expect(info.preferredVernacular(language: nil) == nil)
    }
}
