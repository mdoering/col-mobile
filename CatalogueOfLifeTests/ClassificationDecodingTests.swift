import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Classification decoding")
struct ClassificationDecodingTests {
    @Test("Classification array decodes ordered root → parent")
    func decodes() throws {
        let data = try FixtureLoader.data("classification_felis_catus")
        let dtos = try JSONDecoder().decode([ClassificationEntryDTO].self, from: data)
        let items = dtos.map { ClassificationItem(id: $0.id, name: $0.name, rank: Rank(apiValue: $0.rank)) }
        #expect(!items.isEmpty)
        #expect(items.first?.rank == .domain || items.first?.rank == .kingdom)
        #expect(items.last?.rank == .genus)
    }
}
