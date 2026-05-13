import SwiftUI

/// For taxa at the genus level or below — where a taxonomic-group sunburst doesn't make sense —
/// summarize what's below this taxon by counting immediate children grouped by their rank.
struct DescendantsByRankView: View {
    let children: [TreeNode]
    /// Called when the user taps a bucket — opens search scoped to this rank
    /// under the parent taxon.
    var onTap: ((Rank) -> Void)? = nil

    private struct Bucket: Identifiable {
        let rank: Rank
        let directCount: Int
        let deeperCount: Int                 // sum of each child's `count` field (descendants beyond direct children)
        var id: String { rank.rawValue }
    }

    private var buckets: [Bucket] {
        let groups = Dictionary(grouping: children, by: \.rank)
        return groups
            .map { rank, nodes in
                Bucket(
                    rank: rank,
                    directCount: nodes.count,
                    deeperCount: nodes.reduce(0) { $0 + $1.count }
                )
            }
            .sorted { $0.rank.sortOrder < $1.rank.sortOrder }
    }

    var body: some View {
        if buckets.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Descendants").font(.headline)
                ForEach(buckets) { b in
                    Button {
                        onTap?(b.rank)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(b.directCount) \(label(rank: b.rank, count: b.directCount))")
                                .font(.callout)
                            if b.deeperCount > 0 {
                                Text("(+ \(b.deeperCount) deeper)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if onTap != nil {
                                Image(systemName: "chevron.forward")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(onTap == nil)
                }
            }
        }
    }

    private func label(rank: Rank, count: Int) -> String {
        let raw = rank.rawValue
        if count == 1 { return raw }
        // Naive pluralization sufficient for botanical/zoological rank names.
        switch rank {
        case .genus:     return "genera"
        case .species:   return "species"           // already plural
        case .subspecies: return "subspecies"
        case .series:    return "series"
        case .form:      return "forms"
        case .variety:   return "varieties"
        case .family:    return "families"
        case .subfamily: return "subfamilies"
        case .superfamily: return "superfamilies"
        case .class:     return "classes"
        case .subclass:  return "subclasses"
        case .infraclass: return "infraclasses"
        case .superclass: return "superclasses"
        default:         return raw + "s"
        }
    }
}
