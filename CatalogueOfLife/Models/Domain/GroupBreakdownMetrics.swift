import Foundation

/// Metrics for a TaxGroup, sourced from /nameusage/search?group=…&facet=rank&facet=status.
struct GroupBreakdownMetrics: Equatable, Sendable {
    let total: Int
    /// Counts per rank.
    let taxaByRank: [Rank: Int]
    /// Counts per status (raw API value as the key).
    let countsByStatus: [String: Int]
}
