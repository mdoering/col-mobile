import Foundation

/// Minimal wire shape for `GET /v1/occurrence/search`. We only decode the fields we use:
/// count + facets. (The `results` array is decoded for the image-fetch path via a separate DTO.)
struct OccurrenceSearchDTO: Decodable, Sendable {
    let count: Int
    let facets: [FacetDTO]?

    struct FacetDTO: Decodable, Sendable {
        let field: String
        let counts: [FacetCountDTO]
    }

    struct FacetCountDTO: Decodable, Sendable {
        let name: String
        let count: Int
    }
}
