import Foundation

/// Wire shape for `GET /dataset/{key}/taxon/{id}/breakdown` — a flat array of recursive entries.
struct TaxonBreakdownEntryDTO: Decodable, Sendable {
    let id: String
    let name: String
    let rank: String?
    let status: String?
    let species: Int?
    let children: [TaxonBreakdownEntryDTO]?
}
