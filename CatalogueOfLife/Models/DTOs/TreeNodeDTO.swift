import Foundation

struct TreeNodeDTO: Decodable, Sendable {
    let id: String
    let parentId: String?
    let name: String
    let authorship: String?
    let rank: String?
    let status: String?
    let count: Int?
    let childCount: Int?
}
