import Foundation

/// Recursive group-based breakdown of a dataset.
struct BreakdownNode: Equatable, Identifiable, Hashable, Sendable {
    let id: String
    let group: String?
    let count: Int
    let children: [BreakdownNode]
}

extension BreakdownNode {
    init(dto: BreakdownEntryDTO, path: String = "") {
        let label = dto.group ?? "_"
        let id = path.isEmpty ? label : "\(path)/\(label)"
        self.init(
            id: id,
            group: dto.group,
            count: dto.count,
            children: (dto.breakdown ?? []).map { BreakdownNode(dto: $0, path: id) }
        )
    }
}
