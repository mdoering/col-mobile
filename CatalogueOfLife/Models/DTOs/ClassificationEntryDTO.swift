import Foundation

struct ClassificationEntryDTO: Decodable, Sendable {
    let id: String
    let name: String
    let rank: String?
    let authorship: String?
}
