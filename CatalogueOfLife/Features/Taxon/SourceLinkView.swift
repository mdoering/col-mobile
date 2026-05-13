import SwiftUI

struct SourceLinkView: View {
    @Environment(AppState.self) private var appState
    let sourceDatasetKey: Int
    let onSelect: () -> Void

    @State private var source: Source?
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source").font(.headline)
            if let source {
                Button(action: onSelect) {
                    HStack {
                        Image(systemName: "books.vertical")
                        Text(source.alias ?? source.title)
                        Spacer()
                        Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.tertiary)
                    }
                    .font(.callout)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            } else if loaded {
                HStack {
                    Image(systemName: "books.vertical")
                    Text("Catalogue of Life")
                }
                .font(.callout)
                .padding(.vertical, 6)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .task(id: sourceDatasetKey) {
            loaded = false
            guard let key = appState.selectedDataset?.key else { loaded = true; return }
            source = try? await APIClientLive().getSource(datasetKey: key, sourceKey: sourceDatasetKey)
            loaded = true
        }
    }
}
