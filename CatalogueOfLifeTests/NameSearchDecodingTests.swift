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

    @Test("NameSearchResponseDTO decodes the no-hit response (no result key)")
    func searchResponseEmpty() throws {
        // The API omits `result` entirely when total=0; that response must
        // still decode cleanly into an empty SearchResult, not throw.
        let json = #"{"offset":0,"limit":25,"total":0,"empty":true,"last":true}"#
        let dto = try JSONDecoder().decode(NameSearchResponseDTO.self, from: Data(json.utf8))
        let result = SearchResult(dto: dto)
        #expect(result.total == 0)
        #expect(result.hits.isEmpty)
        #expect(result.facets.isEmpty)
    }

    @Test("NameSearchResponseDTO decodes hits + facets into a SearchResult")
    func searchResponseWithFacets() throws {
        let json = """
        {
          "total": 481,
          "result": [{
              "usage": {
                "id": "T1",
                "status": "accepted",
                "name": {"scientificName": "Felis catus", "rank": "species"}
              },
              "group": "chordates"
          }],
          "facets": {
            "rank": [
              {"value": "species", "count": 312},
              {"value": "subspecies", "count": 146}
            ],
            "status": [
              {"value": "synonym", "count": 206},
              {"value": "accepted", "count": 77}
            ]
          }
        }
        """
        let dto = try JSONDecoder().decode(NameSearchResponseDTO.self, from: Data(json.utf8))
        let result = SearchResult(dto: dto)
        #expect(result.total == 481)
        #expect(result.hits.count == 1)
        #expect(result.hits[0].scientificName == "Felis catus")
        #expect(result.facets["rank"]?["species"] == 312)
        #expect(result.facets["rank"]?["subspecies"] == 146)
        #expect(result.facets["status"]?["synonym"] == 206)
        // Group facet wasn't requested in this stub response — should be absent.
        #expect(result.facets["group"] == nil)
    }
}
