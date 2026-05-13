import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Import metrics decoding")
struct ImportMetricsDecodingTests {
    @Test("Decodes import metrics fixture into summary + sections")
    func decodes() throws {
        let data = try FixtureLoader.data("import_metrics")
        let dtos = try JSONDecoder().decode([ImportMetricsDTO].self, from: data)
        #expect(dtos.count >= 1)
        let metrics = ImportMetrics(dto: dtos[0])
        #expect(metrics.attempt > 0)
        #expect(!metrics.summary.isEmpty)
        #expect(metrics.summary.contains { $0.id == "nameCount" })
        #expect(metrics.sections.contains { $0.title == "Taxa by rank" })

        // Estimates row must be absent from summary
        #expect(!metrics.summary.contains { $0.id == "estimateCount" })

        // "Names by rank" section must not exist
        #expect(!metrics.sections.contains { $0.title == "Names by rank" })

        // Taxa-by-rank rows must be sorted by rank sort order (ascending)
        let taxaByRank = metrics.sections.first { $0.title == "Taxa by rank" }
        if let taxaByRank, taxaByRank.rows.count >= 2 {
            let sortOrders = taxaByRank.rows.compactMap { $0.rank?.sortOrder }
            #expect(sortOrders.first! < sortOrders.last!)
        }

        // Vernaculars section must be renamed to "Common names"
        #expect(metrics.sections.contains { $0.title == "Common names" })
    }
}
