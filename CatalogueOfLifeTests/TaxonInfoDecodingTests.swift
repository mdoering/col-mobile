import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Taxon info decoding")
struct TaxonInfoDecodingTests {
    @Test("Decodes Felis catus /info fixture")
    func decodesFelisCatus() throws {
        let data = try FixtureLoader.data("taxon_info_felis_catus")
        let dto = try JSONDecoder().decode(TaxonInfoDTO.self, from: data)
        let info = TaxonInfo(dto: dto)
        #expect(info.scientificName == "Felis catus")
        #expect(info.rank == .species)
        #expect(!info.classification.isEmpty)
        #expect(info.classification.contains { $0.rank == .kingdom })
        #expect(info.vernacularNames.contains { $0.country != nil })
        #expect(info.vernacularNames.contains { $0.area != nil })
    }

    @Test("Vernacular names are deduplicated by (name, language), case-insensitive")
    func vernacularsAreDeduplicated() throws {
        let json = """
        {
            "usage": {
                "id": "T1",
                "status": "accepted",
                "name": {"scientificName": "Sciurus carolinensis", "rank": "species"}
            },
            "vernacularNames": [
                {"id": 1, "name": "Grey squirrel", "language": "eng"},
                {"id": 2, "name": "grey squirrel", "language": "ENG"},
                {"id": 3, "name": "Grey squirrel", "language": "deu"},
                {"id": 4, "name": "Eichhörnchen", "language": "deu"}
            ]
        }
        """
        let dto = try JSONDecoder().decode(TaxonInfoDTO.self, from: Data(json.utf8))
        let info = TaxonInfo(dto: dto)
        // Expect: "Grey squirrel/eng" once, "Grey squirrel/deu" once, "Eichhörnchen/deu" once.
        #expect(info.vernacularNames.count == 3)
        #expect(info.vernacularNames.filter { $0.name.lowercased() == "grey squirrel" && $0.language == "eng" }.count == 1)
    }
}
