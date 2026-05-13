import Foundation

/// Wire shape of `GET /dataset/{key}/name/{nameId}` — only the fields we need to
/// build a display label. The server already returns a pre-formatted `label`.
struct NameDTO: Decodable, Sendable {
    let scientificName: String?
    let authorship: String?
    let label: String?
    let labelHtml: String?
}
