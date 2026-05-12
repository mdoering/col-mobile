import Foundation

struct SuggestEntryDTO: Decodable, Sendable {
    let match: String?
    let context: String?
    let usageId: String
    let rank: String?
    let status: String?
    let group: String?
    let suggestion: String
}
