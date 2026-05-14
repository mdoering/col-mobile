import Foundation

/// `GET /dataset/{key}/nameusage/search` response, decoded for both the hit
/// list and any requested facets in one pass. The existing
/// `NameSearchFacetsDTO` only captures `total + facets` (used by the
/// group-metrics path with `limit=0`); this shape is the full thing.
struct NameSearchResponseDTO: Decodable, Sendable {
    let total: Int?
    let result: [NameUsageSearchHitDTO]
    let facets: [String: [Entry]]?

    struct Entry: Decodable, Sendable {
        let value: String
        let count: Int
    }
}

extension SearchResult {
    init(dto: NameSearchResponseDTO) {
        var facetMap: [String: [String: Int]] = [:]
        for (key, entries) in dto.facets ?? [:] {
            var bucket: [String: Int] = [:]
            for entry in entries {
                bucket[entry.value] = entry.count
            }
            facetMap[key] = bucket
        }
        self.init(
            total: dto.total ?? 0,
            hits: dto.result.map(SearchHit.init(dto:)),
            facets: facetMap
        )
    }
}
