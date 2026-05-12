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
    }
}
