import Foundation

struct SearchHit: Equatable, Identifiable, Sendable {
    let id: String
    let scientificName: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let acceptedId: String?
    let group: String?

    /// Taxon id to navigate to on row tap. Returns nil for a synonym hit whose
    /// accepted target wasn't included in the response — callers should disable the row.
    var navigationTaxonId: String? {
        if let accepted = acceptedId { return accepted }
        return status.isSynonym ? nil : id
    }
}
