import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("GBIF metrics decoding")
struct GBIFMetricsDecodingTests {
    @Test("Decodes Felis catus occurrence metrics fixture")
    func decodes() throws {
        let data = try FixtureLoader.data("gbif_occurrence_metrics")
        let dto = try JSONDecoder().decode(OccurrenceSearchDTO.self, from: data)
        let metrics = GBIFMetrics(dto: dto)
        #expect(metrics.occurrenceCount > 0)
        #expect(metrics.distinctCountries > 0)
        #expect(metrics.distinctDatasets > 0)
        #expect(!metrics.topCountries.isEmpty)
        #expect(metrics.topCountries.count <= 3)
    }
}
