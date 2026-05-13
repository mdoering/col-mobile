import SwiftUI

struct SynonymyView: View {
    let groups: [SynonymyGroup]

    private static let defaultLimit = 4

    @State private var expanded = false

    private var totalEntries: Int {
        groups.reduce(0) { $0 + $1.entries.count }
    }

    /// Truncate to at most `limit` entries while preserving group order.
    /// Each group's `entries` may be partially shown.
    private func truncated(limit: Int) -> [SynonymyGroup] {
        var remaining = limit
        var out: [SynonymyGroup] = []
        for group in groups {
            if remaining <= 0 { break }
            let take = min(remaining, group.entries.count)
            if take < group.entries.count {
                out.append(SynonymyGroup(id: group.id, kind: group.kind, entries: Array(group.entries.prefix(take))))
            } else {
                out.append(group)
            }
            remaining -= take
        }
        return out
    }

    var body: some View {
        if groups.isEmpty {
            EmptyView()
        } else {
            let visible = expanded ? groups : truncated(limit: Self.defaultLimit)
            VStack(alignment: .leading, spacing: 8) {
                Text("Synonyms and combinations").font(.headline)
                ForEach(visible) { group in
                    groupView(group)
                }
                if totalEntries > Self.defaultLimit {
                    Button {
                        expanded.toggle()
                    } label: {
                        Text(expanded ? "Show fewer" : "Show all \(totalEntries) synonyms")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func groupView(_ group: SynonymyGroup) -> some View {
        switch group.kind {
        case .homotypic:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(group.entries) { entry in
                    entryRow(entry, symbol: "≡", indent: 0)
                }
            }
        case .heterotypic:
            VStack(alignment: .leading, spacing: 4) {
                if let first = group.entries.first {
                    entryRow(first, symbol: "=", indent: 0)
                }
                ForEach(group.entries.dropFirst()) { entry in
                    entryRow(entry, symbol: "≡", indent: 1)
                }
            }
        }
    }

    private func entryRow(_ entry: SynonymyEntry, symbol: String, indent: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.scientificName).italic()
                if let auth = entry.authorship {
                    Text(auth).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(indent) * 16)
    }
}
