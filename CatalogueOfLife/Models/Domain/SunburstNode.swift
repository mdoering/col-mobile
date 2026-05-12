import Foundation

/// Generic input to `SunburstView`. Concrete sources (BreakdownNode, TreeNode children)
/// map into this shape.
struct SunburstNode: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let count: Int
    let children: [SunburstNode]
}

extension SunburstNode {
    /// Map a `BreakdownNode` tree into the renderer shape.
    static func from(breakdown: BreakdownNode) -> SunburstNode {
        SunburstNode(
            id: breakdown.id,
            label: breakdown.group ?? "—",
            count: breakdown.count,
            children: breakdown.children.map(SunburstNode.from(breakdown:))
        )
    }
}
