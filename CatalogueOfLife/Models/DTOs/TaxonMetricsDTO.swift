import Foundation

/// Wire shape for `GET /dataset/{key}/taxon/{id}/metrics`. We only decode the fields we display.
struct TaxonMetricsDTO: Decodable, Sendable {
    let taxonCount: Int?
    let taxaByRankCount: [String: Int]?
    let sourceDatasetKeys: [Int]?
}
