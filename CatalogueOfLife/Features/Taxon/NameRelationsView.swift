import SwiftUI

struct NameRelationsView: View {
    @Environment(AppState.self) private var appState
    let relations: [NameRelation]

    /// Resolved labels keyed by relatedNameId. Loaded lazily on appear so
    /// rows render immediately even before the labels arrive.
    @State private var labels: [String: String] = [:]
    /// Wire-value → canonical label resolved from the `nomRelType` vocab.
    @State private var typeLabels: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name relations").font(.headline)
            ForEach(relations) { rel in
                HStack(alignment: .firstTextBaseline) {
                    Text(typeLabel(for: rel.type)).font(.callout)
                    Spacer()
                    // Rows are deliberately non-tappable: name relations almost
                    // always point at synonyms, and we don't open synonym
                    // pages — only accepted taxa get their own detail view.
                    Text(displayLabel(for: rel))
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
            }
        }
        .task(id: relations.map(\.id).joined()) {
            await resolveLabels()
            await loadTypeLabels()
        }
    }

    /// Looks up the canonical label from the cached `nomRelType` vocab. The
    /// vocab's `label` field is already properly cased ("Has basionym"), so
    /// no further transformation is needed. Falls back to the wire value
    /// (capitalised, underscores → spaces) when the vocab isn't loaded yet
    /// or the value is unknown.
    private func typeLabel(for wire: String) -> String {
        if let label = typeLabels[wire] { return label }
        return wire.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func loadTypeLabels() async {
        let client = APIClientLive()
        var newLabels: [String: String] = [:]
        for type in Set(relations.map(\.type)) {
            if let label = await VocabStore.shared.nomRelTypeLabel(for: type, client: client) {
                newLabels[type] = label
            }
        }
        typeLabels = newLabels
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
