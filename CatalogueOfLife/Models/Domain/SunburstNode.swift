import Foundation

/// Generic input to `SunburstView`. Concrete sources (BreakdownNode, TreeNode children)
/// map into this shape.
struct SunburstNode: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let count: Int
    let rank: Rank?
    let children: [SunburstNode]
}

extension SunburstNode {
    /// Map a `BreakdownNode` tree into the renderer shape.
    static func from(breakdown: BreakdownNode) -> SunburstNode {
        SunburstNode(
            id: breakdown.id,
            label: breakdown.group ?? "—",
            count: breakdown.count,
            rank: nil,
            children: breakdown.children.map(SunburstNode.from(breakdown:))
        )
    }

    /// Map a `TaxonBreakdownEntryDTO` into the renderer shape.
    static func from(taxonBreakdown dto: TaxonBreakdownEntryDTO) -> SunburstNode {
        SunburstNode(
            id: dto.id,
            label: dto.name,
            count: max(dto.species ?? 1, 1),
            rank: dto.rank.map(Rank.init(apiValue:)),
            children: (dto.children ?? []).map(SunburstNode.from(taxonBreakdown:))
        )
    }
}
