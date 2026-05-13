import SwiftUI
import SwiftData

struct TaxonDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    let taxonId: String
    @State private var vm: TaxonDetailViewModel?
    @State private var navigateTo: String?
    @State private var childNodes: [TreeNode] = []
    @State private var showingFeedback = false

    private var isFavorite: Bool {
        guard let key = appState.selectedDataset?.key else { return false }
        return favorites.contains { $0.compositeKey == Favorite.key(datasetKey: key, taxonId: taxonId) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch vm?.state {
                case .loaded(let info):
                    TaxonHeaderView(
                        info: info,
                        preferredVernacular: info.preferredVernacular(language: appState.effectiveVernacularLanguage)
                    )
                    ClassificationChipsView(items: info.classification) { item in
                        navigateTo = item.id
                    }
                    if !childNodes.isEmpty {
                        Divider()
                        if info.rank.isSuprageneric {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Breakdown of \(info.scientificName)").font(.headline)
                                SunburstView(
                                    root: sunburstRoot(for: info),
                                    maxDepth: 1
                                ) { node in
                                    navigateTo = node.id
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)
                            }
                        } else {
                            DescendantsByRankView(children: childNodes)
                        }
                    }
                    if !info.synonymyGroups.isEmpty {
                        Divider()
                        SynonymyView(groups: info.synonymyGroups)
                    }
                    if !info.vernacularNames.isEmpty {
                        Divider()
                        VernacularNamesView(
                            names: info.vernacularNames,
                            preferredLanguage: appState.effectiveVernacularLanguage
                        )
                    }
                    if appState.gbifAvailable {
                        Divider()
                        GBIFSectionView(taxonId: info.taxonId)
                    }
                case .failed(let err):
                    errorView(err)
                case .loading, .none:
                    ProgressView().padding()
                }
            }
            .padding()
        }
        .navigationTitle("Taxon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if case let .loaded(info) = vm?.state {
                    Text(info.rank.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if case let .loaded(info) = vm?.state {
                    HStack(spacing: 8) {
                        Button {
                            showingFeedback = true
                        } label: {
                            Image(systemName: "exclamationmark.bubble")
                        }
                        .accessibilityLabel("Report data issue")

                        Text("COL:\(info.taxonId)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        Button {
                            toggleFavorite(info)
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundStyle(isFavorite ? .yellow : .secondary)
                        }
                        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                    }
                }
            }
        }
        .navigationDestination(item: $navigateTo) { id in
            TaxonDetailView(taxonId: id)
        }
        .sheet(isPresented: $showingFeedback) {
            if case let .loaded(info) = vm?.state, let key = appState.selectedDataset?.key {
                FeedbackSheet(datasetKey: key, taxonId: info.taxonId, scientificName: info.scientificName)
            }
        }
        .task {
            if vm == nil {
                vm = TaxonDetailViewModel(
                    taxonId: taxonId,
                    client: APIClientLive(),
                    getDatasetKey: { [appState] in appState.selectedDataset?.key }
                )
            }
            await vm?.load()
            if case let .loaded(info) = vm?.state, let key = appState.selectedDataset?.key {
                PersistenceStore.bumpRecent(modelContext,
                                             datasetKey: key,
                                             taxonId: info.taxonId,
                                             name: info.scientificName,
                                             rank: info.rank.rawValue,
                                             group: info.group)
            }
            if case let .loaded(info) = vm?.state, let key = appState.selectedDataset?.key {
                if let children = try? await APIClientLive().getTreeChildren(datasetKey: key, parentId: info.taxonId) {
                    childNodes = children
                }
            }
        }
    }

    @ViewBuilder
    private func errorView(_ err: APIError) -> some View {
        VStack(spacing: 8) {
            Text("Couldn't load this taxon").font(.headline)
            Button("Retry") { Task { await vm?.load() } }
                .buttonStyle(.bordered)
        }
    }

    private func sunburstRoot(for info: TaxonInfo) -> SunburstNode {
        SunburstNode(
            id: info.taxonId,
            label: info.scientificName,
            count: childNodes.reduce(0) { $0 + $1.count },
            children: childNodes.map {
                SunburstNode(id: $0.id, label: $0.name, count: max($0.count, 1), children: [])
            }
        )
    }

    private func toggleFavorite(_ info: TaxonInfo) {
        guard let key = appState.selectedDataset?.key else { return }
        let composite = Favorite.key(datasetKey: key, taxonId: info.taxonId)
        if let existing = favorites.first(where: { $0.compositeKey == composite }) {
            modelContext.delete(existing)
        } else {
            let fav = Favorite(datasetKey: key,
                                taxonId: info.taxonId,
                                name: info.scientificName,
                                authorship: info.authorship,
                                rank: info.rank.rawValue,
                                group: info.group)
            modelContext.insert(fav)
        }
        try? modelContext.save()
    }
}
