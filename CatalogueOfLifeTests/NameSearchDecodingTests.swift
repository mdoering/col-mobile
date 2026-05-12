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

    @Test("Synonym hits route to acceptedId when present; nil when missing")
    func synonymRoutesToAccepted() {
        let synonym = SearchHit(
            id: "S1", scientificName: "Felis x", authorship: nil,
            rank: .species, status: .synonym, acceptedId: "ACC1", group: nil
        )
        let accepted = SearchHit(
            id: "ACC2", scientificName: "Felis catus", authorship: nil,
            rank: .species, status: .accepted, acceptedId: nil, group: nil
        )
        let orphanSynonym = SearchHit(
            id: "OS1", scientificName: "Felis ghost", authorship: nil,
            rank: .species, status: .synonym, acceptedId: nil, group: nil
        )
        #expect(synonym.navigationTaxonId == "ACC1")
        #expect(accepted.navigationTaxonId == "ACC2")
        #expect(orphanSynonym.navigationTaxonId == nil)
    }

    @Test("Decodes synonym hit with accepted nested object")
    func decodesSynonymWithAccepted() throws {
        let json = """
        {"offset":0,"limit":1,"total":1,"result":[{
            "usage": {
                "id": "SYN1",
                "status": "synonym",
                "name": {"scientificName": "Felis domestica", "rank": "species"},
                "accepted": {"id": "ACC1"}
            },
            "group": "chordates"
        }]}
        """
        let paged = try JSONDecoder().decode(PagedDTO<NameUsageSearchHitDTO>.self, from: Data(json.utf8))
        let hit = SearchHit(dto: paged.result[0])
        #expect(hit.acceptedId == "ACC1")
        #expect(hit.navigationTaxonId == "ACC1")
        #expect(hit.status == .synonym)
        #expect(hit.group == "chordates")
    }
}
