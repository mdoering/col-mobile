import Foundation

/// Recursive group-based count tree, returned by `GET /dataset/{key}/breakdown`.
struct BreakdownDTO: Decodable, Sendable {
    let datasetKey: Int
    let breakdown: [BreakdownEntryDTO]
}

struct BreakdownEntryDTO: Decodable, Sendable {
    let group: String?
    let count: Int
    let breakdown: [BreakdownEntryDTO]?
}
