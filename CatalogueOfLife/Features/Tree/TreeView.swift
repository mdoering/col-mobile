import SwiftUI

/// One step in the Tree tab's navigation path.
///
/// Owned by `TreeTabRoot` (the wrapper at the Tree tab's NavigationStack), so
/// any inner TreeView can append to the path and the root's destination
/// handler decides whether to push another TreeView (browsing) or a
/// TaxonDetailView (leaf inspection).
enum TreeRoute: Hashable {
    case child(id: String, name: String)
    case taxon(id: String)
}

struct TreeView: View {
    @Environment(AppState.self) private var appState
    let rootParentId: String?         // nil = dataset root
    let rootParentName: String?       // for the nav title
    @Binding var path: [TreeRoute]
    @State private var vm: TreeViewModel?
    /// Set while the suggest-pick is fetching the taxon's classification path.
    @State private var divingIn = false
    /// Fetched once per pushed TreeView (only when rootParentId != nil) so we
    /// can render the chips above the children list. Excludes the current
    /// taxon and "--incertae-sedis--" placeholder ancestors.
    @State private var pathChips: [ClassificationItem] = []

    init(rootParentId: String? = nil, rootParentName: String? = nil, path: Binding<[TreeRoute]>) {
        self.rootParentId = rootParentId
        self.rootParentName = rootParentName
        self._path = path
    }

    var body: some View {
        content
            .navigationTitle(rootParentName ?? "Tree")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    if rootParentId == nil {
                        SuggestField(client: APIClientLive(),
                                     getDatasetKey: { [appState] in appState.selectedDataset?.key }) { suggestion in
                            handlePick(suggestion)
                        }
                        .overlay(alignment: .trailing) {
                            if divingIn {
                                ProgressView().padding(.trailing, 24)
                            }
                        }
                    }
                    if rootParentId != nil, !pathChips.isEmpty {
                        ClassificationChipsView(items: pathChips) { item in
                            popTo(ancestorId: item.id)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
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
                await loadPathChipsIfNeeded()
            }
    }

    @MainActor
    private func loadPathChipsIfNeeded() async {
        guard let taxonId = rootParentId, pathChips.isEmpty,
              let key = appState.selectedDataset?.key else { return }
        let nodes = (try? await APIClientLive().getTreeClassification(datasetKey: key, taxonId: taxonId)) ?? []
        // The endpoint returns the chain in leaf → root order, with the current
        // taxon as the first entry. Drop the current taxon, drop any virtual
        // "Not assigned" placeholders, then reverse so the chips render root
        // → immediate parent — matching the taxon-detail classification chips.
        let ancestorsLeafFirst = nodes.dropFirst().filter { !$0.id.contains("--incertae-sedis--") }
        pathChips = ancestorsLeafFirst.reversed().map {
            ClassificationItem(id: $0.id, name: $0.name, rank: $0.rank)
        }
    }

    /// Pop the navigation stack back to the matching ancestor entry. If the
    /// ancestor is not in the path (e.g. came in via a different drill path),
    /// reset to root.
    ///
    /// The mutation is deferred one runloop tick: NavigationStack reads its
    /// path through a Binding, and assigning a shorter array from inside a
    /// destination view that's about to be torn down can leave SwiftUI's
    /// internal navigation history out of sync (the back button then walks
    /// the popped views as if they were still pushed). Deferring lets the
    /// tap handler return cleanly first, after which the truncation pops the
    /// stack atomically.
    private func popTo(ancestorId: String) {
        let newPath: [TreeRoute]
        if let idx = path.lastIndex(where: {
            if case let .child(id, _) = $0 { return id == ancestorId } else { return false }
        }) {
            newPath = Array(path.prefix(through: idx))
        } else {
            newPath = []
        }
        Task { @MainActor in
            path = newPath
        }
    }

    private func handlePick(_ suggestion: TaxonSuggestion) {
        guard let key = appState.selectedDataset?.key else {
            // No dataset yet — nothing we can do.
            return
        }
        divingIn = true
        Task { @MainActor in
            defer { divingIn = false }
            do {
                let classification = try await APIClientLive().getTreeClassification(datasetKey: key, taxonId: suggestion.id)
                // The endpoint returns ancestors plus the picked taxon. Push every
                // step as a `.child(...)` route so the user can back through the
                // whole lineage (root → kingdom → … → picked).
                let routes = classification.map { TreeRoute.child(id: $0.id, name: $0.name) }
                path.append(contentsOf: routes)
            } catch {
                // Fall back to opening the taxon detail directly so the user
                // still gets *somewhere* useful when /tree/{id} is unreachable.
                path.append(.taxon(id: suggestion.id))
            }
        }
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
                                path.append(.child(id: node.id, name: node.name))
                            } else {
                                path.append(.taxon(id: node.id))
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
                                    path.append(.child(id: node.id, name: node.name))
                                } else {
                                    path.append(.taxon(id: node.id))
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
