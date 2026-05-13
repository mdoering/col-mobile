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

    /// True when the API returned a synthetic "Not assigned" pseudo-node for
    /// children that lack a parent at the next rank. Detected by the ID
    /// suffix the server emits when `insertPlaceholder=true` is set on the
    /// tree request, e.g. `CS5HF--incertae-sedis--KINGDOM`. Placeholders are
    /// browsable like real taxa but must not open as taxon details.
    var isPlaceholder: Bool { id.contains("--incertae-sedis--") }
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
