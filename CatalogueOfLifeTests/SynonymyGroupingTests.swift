import Testing
@testable import CatalogueOfLife

// The real API returns synonyms as a structured dict (not a flat list):
//   homotypic:          [SynonymEntryDTO]
//   heterotypic:        [SynonymEntryDTO]   (flat union, parallel to heterotypicGroups)
//   heterotypicGroups:  [[SynonymEntryDTO]] (basionym buckets)
// These tests construct structured inputs and verify SynonymyGroup.group(synonymsDTO:).

@Suite("Synonymy grouping")
struct SynonymyGroupingTests {

    private func synonymEntry(_ id: String, name: String = "X", rank: String = "species") -> TaxonInfoDTO.SynonymEntryDTO {
        TaxonInfoDTO.SynonymEntryDTO(
            id: id,
            name: TaxonInfoDTO.NameDTO(scientificName: name, authorship: nil, rank: rank),
            status: "synonym"
        )
    }

    @Test("Homotypic entries form one homotypic group; each basionym bucket is a separate heterotypic group")
    func homotypicAndHeterotypicGroups() {
        let dto = TaxonInfoDTO.SynonymsDTO(
            homotypic: [synonymEntry("H1"), synonymEntry("H2")],
            heterotypic: [synonymEntry("A1"), synonymEntry("B1"), synonymEntry("B2")],
            heterotypicGroups: [
                [synonymEntry("A1", name: "A one")],
                [synonymEntry("B1", name: "B one"), synonymEntry("B2", name: "B two")]
            ]
        )
        let groups = SynonymyGroup.group(synonymsDTO: dto, parentId: "T1")
        let homo = groups.filter { $0.kind == .homotypic }
        let hetero = groups.filter { $0.kind == .heterotypic }
        #expect(homo.count == 1)
        #expect(homo.first?.entries.count == 2)
        #expect(hetero.count == 2)
        #expect(hetero.first?.entries.count == 1)
        #expect(hetero.last?.entries.count == 2)
    }

    @Test("Heterotypic-only input (via heterotypicGroups) emits only heterotypic groups")
    func heterotypicOnly() {
        let dto = TaxonInfoDTO.SynonymsDTO(
            homotypic: [],
            heterotypic: [synonymEntry("X1"), synonymEntry("X2")],
            heterotypicGroups: [
                [synonymEntry("X1", name: "X one")],
                [synonymEntry("X2", name: "X two")]
            ]
        )
        let groups = SynonymyGroup.group(synonymsDTO: dto, parentId: "T1")
        #expect(groups.allSatisfy { $0.kind == .heterotypic })
        #expect(groups.count == 2)
    }

    @Test("Empty input yields no groups")
    func emptyInput() {
        let dto = TaxonInfoDTO.SynonymsDTO(
            homotypic: [],
            heterotypic: [],
            heterotypicGroups: []
        )
        #expect(SynonymyGroup.group(synonymsDTO: dto, parentId: "T1").isEmpty)
    }
}
