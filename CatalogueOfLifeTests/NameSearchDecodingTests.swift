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
            rank: .species, status: .synonym, acceptedId: "ACC1", acceptedName: nil, group: nil,
            merged: false, extinct: false, vernacularNames: []
        )
        let accepted = SearchHit(
            id: "ACC2", scientificName: "Felis catus", authorship: nil,
            rank: .species, status: .accepted, acceptedId: nil, acceptedName: nil, group: nil,
            merged: false, extinct: false, vernacularNames: []
        )
        let orphanSynonym = SearchHit(
            id: "OS1", scientificName: "Felis ghost", authorship: nil,
            rank: .species, status: .synonym, acceptedId: nil, acceptedName: nil, group: nil,
            merged: false, extinct: false, vernacularNames: []
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
                "accepted": {"id": "ACC1", "name": {"scientificName": "Felis catus"}}
            },
            "group": "chordates"
        }]}
        """
        let paged = try JSONDecoder().decode(PagedDTO<NameUsageSearchHitDTO>.self, from: Data(json.utf8))
        let hit = SearchHit(dto: paged.result[0])
        #expect(hit.acceptedId == "ACC1")
        #expect(hit.acceptedName == "Felis catus")
        #expect(hit.navigationTaxonId == "ACC1")
        #expect(hit.status == .synonym)
        #expect(hit.group == "chordates")
    }

    @Test("Synonym hits carry the accepted scientific name")
    func synonymCarriesAcceptedName() throws {
        let data = try FixtureLoader.data("name_search_synonyms")
        let paged = try JSONDecoder().decode(PagedDTO<NameUsageSearchHitDTO>.self, from: data)
        let hits = paged.result.map(SearchHit.init(dto:))
        let synonymWithAccepted = hits.first { $0.status.isSynonym && $0.acceptedName != nil }
        #expect(synonymWithAccepted != nil, "Fixture should contain at least one synonym with an accepted name")
        #expect(synonymWithAccepted?.acceptedName?.isEmpty == false)
    }
}
