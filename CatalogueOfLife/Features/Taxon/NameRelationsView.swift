import SwiftUI

struct NameRelationsView: View {
    @Environment(AppState.self) private var appState
    let relations: [NameRelation]
    let onSelect: (String) -> Void  // related usageId → push detail

    /// Resolved labels keyed by relatedNameId. Loaded lazily on appear so
    /// rows are interactive immediately even before the labels arrive.
    @State private var labels: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name relations").font(.headline)
            ForEach(relations) { rel in
                HStack(alignment: .firstTextBaseline) {
                    Text(rel.type.capitalized).font(.callout)
                    Spacer()
                    if let related = rel.relatedUsageId {
                        Button {
                            onSelect(related)
                        } label: {
                            Text(displayLabel(for: rel))
                                .font(.caption)
                                .italic()
                                .foregroundStyle(.tint)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .task(id: relations.map(\.id).joined()) {
            await resolveLabels()
        }
    }

    private func displayLabel(for rel: NameRelation) -> String {
        if let nameId = rel.relatedNameId, let label = labels[nameId] {
            return label
        }
        // Fallback while loading or when the relation has no nameId.
        return rel.relatedUsageId.map { "COL:\($0)" } ?? "—"
    }

    private func resolveLabels() async {
        guard let datasetKey = appState.selectedDataset?.key else { return }
        let client = APIClientLive()
        let missing = relations.compactMap(\.relatedNameId).filter { labels[$0] == nil }
        await withTaskGroup(of: (String, String?).self) { group in
            for nameId in missing {
                group.addTask {
                    let label = try? await client.getNameLabel(datasetKey: datasetKey, nameId: nameId)
                    return (nameId, label)
                }
            }
            for await (nameId, label) in group {
                if let label { labels[nameId] = label }
            }
        }
    }
}
