import Foundation

struct TreeNode: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let count: Int
    let childCount: Int

    var isLeaf: Bool { childCount == 0 }
}

extension TreeNode {
    init(dto: TreeNodeDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            authorship: dto.authorship,
            rank: Rank(apiValue: dto.rank),
            status: TaxonStatus(apiValue: dto.status),
            count: dto.count ?? 0,
            childCount: dto.childCount ?? 0
        )
    }
}
