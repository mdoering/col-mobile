import SwiftUI

struct TreeView: View {
    @Environment(AppState.self) private var appState
    let rootParentId: String?         // nil = dataset root
    let rootParentName: String?       // for the nav title
    @State private var vm: TreeViewModel?
    @State private var nextParent: TreeChildTarget?   // bundled id+name for non-leaf push
    @State private var nextLeafId: String?            // for leaf -> TaxonDetailView

    /// Pushed via navigationDestination(item:) so SwiftUI receives id + name
    /// in one observation tick. Two separate @State vars was racy — the
    /// destination closure occasionally fired with stale captured state and
    /// the pushed TreeView's title fell back to "Tree".
    struct TreeChildTarget: Hashable, Identifiable {
        let id: String
        let name: String
    }

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
            .navigationDestination(item: $nextParent) { target in
                TreeView(rootParentId: target.id, rootParentName: target.name)
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
                            // Tapping the name drills into children. For leaf
                            // taxa there are no children, so fall through to
                            // opening the taxon detail. Placeholders always
                            // drill (they have no detail view).
                            if node.isPlaceholder || !node.isLeaf {
                                nextParent = TreeChildTarget(id: node.id, name: node.name)
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
                                // Chevron now opens taxon details. Placeholders
                                // are the exception — they have no detail page,
                                // so the chevron still drills into children.
                                if node.isPlaceholder {
                                    nextParent = TreeChildTarget(id: node.id, name: node.name)
                                } else {
                                    nextLeafId = node.id
                                }
                            } label: {
                                Image(systemName: node.isPlaceholder ? "chevron.forward.2" : "chevron.forward")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(node.isPlaceholder ? "Browse children of \(node.name)" : "Open \(node.name) details")
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
