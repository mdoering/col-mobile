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
            // Re-fire when the resolved dataset key arrives (cold-launch race) or changes.
            .task(id: appState.selectedDataset?.key) {
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
                    HStack(spacing: 8) {
                        Button {
                            if node.isPlaceholder {
                                // Synthetic "Not assigned" pseudo-node — drill
                                // into its children instead of opening a detail.
                                nextParentName = node.name
                                nextParentId = node.id
                            } else {
                                nextLeafId = node.id
                            }
                        } label: {
                            TreeRowView(node: node)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if !node.isLeaf {
                            Button {
                                nextParentName = node.name
                                nextParentId = node.id
                            } label: {
                                Image(systemName: "chevron.forward.2")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Browse children of \(node.name)")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 8))
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
