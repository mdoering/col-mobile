import Foundation

struct ImportMetricsDTO: Decodable, Sendable {
    let attempt: Int
    let datasetKey: Int
    let started: String?
    let finished: String?
    let state: String?
    let nameCount: Int?
    let taxonCount: Int?
    let synonymCount: Int?
    let vernacularCount: Int?
    let referenceCount: Int?
    let distributionCount: Int?
    let mediaCount: Int?
    let estimateCount: Int?
    let treatmentCount: Int?
    let typeMaterialCount: Int?
    let verbatimCount: Int?
    let taxaByRankCount: [String: Int]?
    let synonymsByRankCount: [String: Int]?
    let namesByRankCount: [String: Int]?
    let namesByStatusCount: [String: Int]?
    let vernacularsByLanguageCount: [String: Int]?
}
