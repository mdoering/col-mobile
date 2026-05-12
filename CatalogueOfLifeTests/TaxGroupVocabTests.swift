import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("TaxGroup vocab decoding")
struct TaxGroupVocabTests {
    @Test("Decodes the full vocab fixture")
    func decodesVocab() throws {
        let data = try FixtureLoader.data("vocab_taxgroup")
        let dtos = try JSONDecoder().decode([TaxGroupVocabDTO].self, from: data)
        let groups = dtos.map(TaxGroup.init(dto:))
        #expect(groups.count > 10)
        #expect(groups.contains { $0.name == "viruses" })
        #expect(groups.contains { $0.codes.contains("bacterial") })
    }
}
