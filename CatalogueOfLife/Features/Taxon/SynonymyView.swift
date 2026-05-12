import SwiftUI

struct SynonymyView: View {
    let groups: [SynonymyGroup]

    var body: some View {
        if groups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Synonyms and combinations").font(.headline)
                ForEach(groups) { group in
                    groupView(group)
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
