import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Name search decoding")
struct NameSearchDecodingTests {
    @Test("Decodes felis search fixture")
    func decodesFelis() throws {
        let data = try FixtureLoader.data("name_search_felis")
        let paged = try JSONDecoder().decode(PagedDTO<NameUsageSearchHitDTO>.self, from: data)
        let hits = paged.result.map(SearchHit.init(dto:))
        #expect(!hits.isEmpty)
        #expect(hits.contains { $0.scientificName.localizedCaseInsensitiveContains("Felis") })
    }

    @Test("Synonym hits route to acceptedId when present")
    func synonymRoutesToAccepted() {
        let synonym = SearchHit(
            id: "S1", scientificName: "Felis x", authorship: nil,
            rank: .species, status: .synonym, acceptedId: "ACC1", group: nil
        )
        let accepted = SearchHit(
            id: "ACC2", scientificName: "Felis catus", authorship: nil,
            rank: .species, status: .accepted, acceptedId: nil, group: nil
        )
        #expect(synonym.navigationTaxonId == "ACC1")
        #expect(accepted.navigationTaxonId == "ACC2")
    }
}
