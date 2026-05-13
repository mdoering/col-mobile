import Foundation

struct TaxonMetrics: Equatable, Sendable {
    let taxonCount: Int
    let taxaByRankCount: [Rank: Int]
    let sourceCount: Int
}

extension TaxonMetrics {
    init(dto: TaxonMetricsDTO) {
        var byRank: [Rank: Int] = [:]
        for (key, value) in dto.taxaByRankCount ?? [:] {
            byRank[Rank(apiValue: key)] = value
        }
        self.init(
            taxonCount: dto.taxonCount ?? 0,
            taxaByRankCount: byRank,
            sourceCount: dto.sourceDatasetKeys?.count ?? 0
        )
    }
}
