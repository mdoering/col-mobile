import SwiftUI
import SwiftData

struct TaxonDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    let taxonId: String
    @State private var vm: TaxonDetailViewModel?
    @State private var navigateTo: String?
    @State private var navigateToSourceKey: Int?
    @State private var childNodes: [TreeNode] = []
    @State private var breakdownChildren: [SunburstNode] = []
    @State private var showingFeedback = false
    @State private var fullScreenSunburst: SunburstNode?

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
                    if let citation = info.publishedInCitation, !citation.isEmpty {
                        Divider()
                        PublishedInView(citation: citation)
                    }
                    if info.rank.isSuprageneric {
                        if !breakdownChildren.isEmpty {
                            Divider()
                            let breakdownRoot = SunburstNode(
                                id: info.taxonId,
                                label: info.scientificName,
                                count: breakdownChildren.reduce(0) { $0 + $1.count },
                                rank: info.rank,
                                children: breakdownChildren
                            )
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Breakdown of \(info.scientificName)").font(.headline)
                                    Spacer()
                                    Button {
                                        fullScreenSunburst = breakdownRoot
                                    } label: {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    }
                                    .accessibilityLabel("Open breakdown full screen")
                                }
                                SunburstView(
                                    root: breakdownRoot,
                                    maxDepth: 2
                                ) { node in
                                    navigateTo = node.id
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 320)
                            }
                        }
                    } else {
                        if !childNodes.isEmpty {
                            Divider()
                            DescendantsByRankView(children: childNodes) { rank in
                                appState.selectedTabIndex = 1
                                appState.pendingSearchScope = TaxonSearchScope(
                                    taxonId: info.taxonId,
                                    label: info.scientificName,
                                    rank: rank
                                )
                            }
                        }
                    }
                    if let ety = info.etymology, !ety.isEmpty {
                        Divider()
                        RemarksView(title: "Etymology", text: ety)
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
                    if !info.nameRelations.isEmpty {
                        Divider()
                        NameRelationsView(relations: info.nameRelations)
                    }
                    if !info.typeMaterials.isEmpty {
                        Divider()
                        TypeMaterialView(entries: info.typeMaterials)
                    }
                    if let sourceKey = info.sourceDatasetKey {
                        Divider()
                        SourceLinkView(sourceDatasetKey: sourceKey) {
                            navigateToSourceKey = sourceKey
                        }
                    }
                    if let r = info.remarks, !r.isEmpty {
                        Divider()
                        RemarksView(title: "Remarks", text: r)
                    }
                    Divider()
                    GBIFSectionView(taxonId: info.taxonId)
                    if let key = appState.selectedDataset?.key,
                       let url = URL(string: "https://www.checklistbank.org/dataset/\(key)/taxon/\(info.taxonId)") {
                        Divider()
                        Link(destination: url) {
                            HStack {
                                Text("Open in ChecklistBank").font(.callout)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                        .padding(.top, 4)
                    }
                    if let gbifURL = URL(string: "https://demo.gbif.org/occurrence/search?checklistKey=7ddf754f-d193-4cc9-b351-99906754a03b&taxonKey=\(info.taxonId)") {
                        Link(destination: gbifURL) {
                            HStack {
                                Text("Open in GBIF").font(.callout)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
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
                    HStack(spacing: 6) {
                        Text(info.rank.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(info.taxonId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
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
        .navigationDestination(item: $navigateToSourceKey) { key in
            SourceDetailView(sourceKey: key)
        }
        .sheet(isPresented: $showingFeedback) {
            if case let .loaded(info) = vm?.state, let key = appState.selectedDataset?.key {
                if appState.hasValidUserEmail {
                    FeedbackSheet(datasetKey: key, taxonId: info.taxonId, scientificName: info.scientificName, userEmail: appState.userEmail!)
                } else {
                    FeedbackEmailMissingView()
                }
            }
        }
        .fullScreenCover(item: $fullScreenSunburst) { root in
            SunburstFullScreenView(
                root: root,
                maxDepth: 2,
                popoverKind: .taxon
            ) { node in
                navigateTo = node.id
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
                if info.rank.isSuprageneric {
                    if let nodes = try? await APIClientLive().getTaxonBreakdown(datasetKey: key, taxonId: info.taxonId) {
                        breakdownChildren = nodes
                    }
                } else {
                    if let page = try? await APIClientLive().getTreeChildren(datasetKey: key, parentId: info.taxonId, offset: 0) {
                        childNodes = page.nodes
                    }
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

private struct FeedbackEmailMissingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Set your email first",
                systemImage: "envelope",
                description: Text("To send feedback you need to configure your email address in About → Preferences.")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
