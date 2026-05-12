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
}
