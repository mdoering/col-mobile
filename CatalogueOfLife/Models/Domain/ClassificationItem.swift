import Foundation

struct ClassificationItem: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let rank: Rank
}
