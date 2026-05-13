import Foundation

struct NameSearchFacetsDTO: Decodable, Sendable {
    let total: Int?
    let facets: [String: [FacetEntry]]?

    struct FacetEntry: Decodable, Sendable {
        let value: String
        let count: Int
    }
}
