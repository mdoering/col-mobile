import SwiftUI

struct TreeView: View {
    @Environment(AppState.self) private var appState
    let rootParentId: String?         // nil = dataset root
    let rootParentName: String?       // for the nav title
    @State private var vm: TreeViewModel?
    @State private var nextParentId: String?      // for non-leaf pushes
    @State private var nextParentName: String?
    @State private var nextLeafId: String?        // for leaf -> TaxonDetailView

    init(rootParentId: String? = nil, rootParentName: String? = nil) {
        self.rootParentId = rootParentId
        self.rootParentName = rootParentName
    }

    var body: some View {
        content
            .navigationTitle(rootParentName ?? "Tree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
            .safeAreaInset(edge: .top) {
                if rootParentId == nil {
                    SuggestField(client: APIClientLive(),
                                 getDatasetKey: { [appState] in appState.selectedDataset?.key }) { suggestion in
                        handlePick(suggestion)
                    }
                }
            }
            .navigationDestination(item: $nextParentId) { id in
                TreeView(rootParentId: id, rootParentName: nextParentName)
            }
            .navigationDestination(item: $nextLeafId) { id in
                TaxonDetailView(taxonId: id)
            }
            .task {
                if vm == nil {
                    vm = TreeViewModel(parentId: rootParentId,
                                        parentName: rootParentName,
                                        client: APIClientLive(),
                                        getDatasetKey: { [appState] in appState.selectedDataset?.key })
                }
                await vm?.load()
            }
    }

    private func handlePick(_ suggestion: TaxonSuggestion) {
        // v1: push the taxon detail directly. The plan's full design says "navigate
        // the tree to that taxon's row using the classification helper" — that requires
        // pre-fetching /classification and synthetically constructing the navigation
        // path. Deferred to a later iteration.
        nextLeafId = suggestion.id
    }

    @ViewBuilder
    private var content: some View {
        switch vm?.state {
        case .loaded(let nodes):
            if nodes.isEmpty {
                ContentUnavailableView("No children", systemImage: "tree", description: Text("This taxon has no listed descendants in the current release."))
            } else {
                List(nodes) { node in
                    Button {
                        if node.isLeaf {
                            nextLeafId = node.id
                        } else {
                            nextParentName = node.name
                            nextParentId = node.id
                        }
                    } label: {
                        TreeRowView(node: node)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        case .failed(let err):
            VStack(spacing: 8) {
                Text("Couldn't load tree").font(.headline)
                Text(String(describing: err)).foregroundStyle(.secondary).font(.caption)
                Button("Retry") { Task { await vm?.load() } }.buttonStyle(.bordered)
            }
        case .loading, .idle, .none:
            ProgressView()
        }
    }
}
