import Foundation

struct SearchHit: Equatable, Identifiable, Sendable {
    let id: String
    let scientificName: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let acceptedId: String?
    let group: String?

    /// The taxon id to navigate to on row tap. Synonyms route to their accepted target.
    var navigationTaxonId: String { acceptedId ?? id }
}
