import Foundation

/// Decode the `results[].media[]` portion of `/v1/occurrence/search`. The metrics path
/// uses a separate DTO that only reads `count + facets`. This path is "image-flavored".
struct OccurrenceWithMediaDTO: Decodable, Sendable {
    let results: [OccurrenceResultDTO]

    struct OccurrenceResultDTO: Decodable, Sendable {
        let gbifID: String?
        let media: [MediaItemDTO]?
    }

    struct MediaItemDTO: Decodable, Sendable {
        let type: String?
        let format: String?
        let identifier: String?
        let references: String?
        let creator: String?
        let publisher: String?
        let license: String?
        let rightsHolder: String?
    }
}
