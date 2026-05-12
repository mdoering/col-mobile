import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Breakdown decoding")
struct BreakdownDecodingTests {
    @Test("Decodes dataset breakdown into a 2-level tree")
    func decodes() throws {
        let data = try FixtureLoader.data("dataset_breakdown")
        let dto = try JSONDecoder().decode(BreakdownDTO.self, from: data)
        let root = BreakdownNode(
            id: "root", group: nil,
            count: dto.breakdown.reduce(0) { $0 + $1.count },
            children: dto.breakdown.map { BreakdownNode(dto: $0) }
        )
        #expect(root.children.count >= 2)
        let groups = Set(root.children.compactMap(\.group))
        #expect(groups.contains("eukaryotes"))
        #expect(root.children.contains { !$0.children.isEmpty })
        #expect(root.count > 0)
    }
}
