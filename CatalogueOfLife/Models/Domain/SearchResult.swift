import Foundation

/// One nameusage/search response: hits + total + per-facet counts.
///
/// `facets` is keyed by facet name ("rank", "status", "group") and maps each
/// returned value to its count. With the API's default `facetIncludeSelf=false`
/// each facet ignores its own active filter — so the rank facet still shows
/// all ranks even when the user has rank=species applied. Facets dimensions
/// the caller didn't request are absent.
struct SearchResult: Equatable, Sendable {
    let total: Int
    let hits: [SearchHit]
    let facets: [String: [String: Int]]

    static let empty = SearchResult(total: 0, hits: [], facets: [:])
}
