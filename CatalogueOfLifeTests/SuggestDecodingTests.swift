import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Suggest decoding")
struct SuggestDecodingTests {
    @Test("Suggest response decodes into TaxonSuggestion list")
    func decodes() throws {
        let data = try FixtureLoader.data("suggest_felis")
        let dtos = try JSONDecoder().decode([SuggestEntryDTO].self, from: data)
        let suggestions = dtos.map(TaxonSuggestion.init(dto:))
        #expect(!suggestions.isEmpty)
        #expect(suggestions.contains { $0.scientificName.localizedCaseInsensitiveContains("Felis") })
    }
}
