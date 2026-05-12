import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SearchViewModel?
    @State private var selectedTaxonId: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
                .navigationDestination(item: $selectedTaxonId) { id in
                    TaxonDetailView(taxonId: id)
                }
        }
        .onAppear { ensureVM() }
    }

    private func ensureVM() {
        if vm == nil {
            vm = SearchViewModel(client: APIClientLive()) { [appState] in
                appState.selectedDataset?.key
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm {
            @Bindable var vm = vm
            ZStack {
                Color.clear
                switch vm.state {
                case .idle:
                    ContentUnavailableView("Search names",
                        systemImage: "magnifyingglass",
                        description: Text("Type to find taxa in \(appState.selectedDataset?.alias ?? "the selected release")."))
                case .loading:
                    ProgressView()
                case let .loaded(hits):
                    resultsList(hits)
                case let .failed(err):
                    errorView(err) { vm.query = vm.query }
                }
            }
            .searchable(text: $vm.query, prompt: "Scientific or vernacular name")
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func resultsList(_ hits: [SearchHit]) -> some View {
        if hits.isEmpty {
            ContentUnavailableView.search
        } else {
            List(hits) { hit in
                if let target = hit.navigationTaxonId {
                    Button { selectedTaxonId = target } label: { SearchRow(hit: hit) }
                        .buttonStyle(.plain)
                } else {
                    // Orphan synonym (no accepted) — show but don't navigate
                    SearchRow(hit: hit)
                        .opacity(0.6)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func errorView(_ err: APIError, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't search").font(.headline)
            Text(message(for: err)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry", action: retry).buttonStyle(.bordered)
        }
        .padding()
    }

    private func message(for err: APIError) -> String {
        switch err {
        case .network: "Network unavailable. Check your connection."
        case .server(let s): "Server error (\(s))."
        case .decoding: "We couldn't understand the response."
        case .notFound: "No matches."
        }
    }
}

private struct SearchRow: View {
    let hit: SearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(hit.scientificName).italic().font(.body)
                if let auth = hit.authorship {
                    Text(auth).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(hit.rank.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
            }
            if hit.status.isSynonym {
                Text("synonym").font(.caption2).foregroundStyle(.orange)
            }
        }
    }
}

// Temporary stub — replaced by Task 14. Lets SearchView compile in isolation.
struct TaxonDetailView: View {
    let taxonId: String
    var body: some View {
        Text("Taxon: \(taxonId)").navigationTitle("Taxon")
    }
}
