import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SearchViewModel?
    @State private var selectedTaxonId: String?
    /// Local mirror of the search text. Decoupling it from `vm.query` (which is
    /// `@Observable`) means typing no longer triggers a full body recompute of
    /// `content` — the FilterMenus and results sub-tree only rebuild when the
    /// VM state actually changes (submit, filter, etc.).
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedTaxonId) { id in
                    TaxonDetailView(taxonId: id)
                }
        }
        .onAppear { ensureVM() }
        .onChange(of: appState.pendingSearchGroup) { _, group in
            guard let group, let vm else { return }
            vm.query = ""
            query = ""
            vm.rank = nil
            vm.status = nil
            vm.group = group
            appState.pendingSearchGroup = nil
        }
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
            VStack(spacing: 0) {
                filterBar(vm: vm)
                results(vm: vm)
            }
            .searchable(text: $query, prompt: "Scientific or vernacular name")
            .submitLabel(.search)
            .onSubmit(of: .search) {
                vm.query = query
                vm.submit()
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func filterBar(vm: SearchViewModel) -> some View {
        @Bindable var vm = vm
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterMenu(
                    title: "Rank",
                    value: vm.rank?.rawValue.capitalized,
                    options: Self.rankOptions,
                    selected: vm.rank?.rawValue,
                    onSelect: { raw in
                        vm.rank = raw.flatMap { Rank(rawValue: $0) }
                        vm.reSearchIfQueryPresent()
                    }
                )
                FilterMenu(
                    title: "Status",
                    value: vm.status?.rawValue.capitalized,
                    options: Self.statusOptions,
                    selected: vm.status?.rawValue,
                    onSelect: { raw in
                        vm.status = raw.flatMap { TaxonStatus(rawValue: $0) }
                        vm.reSearchIfQueryPresent()
                    }
                )
                FilterMenu(
                    title: "Group",
                    value: vm.group?.capitalized,
                    options: Self.groupOptions,
                    selected: vm.group,
                    onSelect: { raw in
                        vm.group = raw
                        vm.reSearchIfQueryPresent()
                    }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private static let rankOptions: [String] = [
        "kingdom", "phylum", "class", "order", "family", "genus", "species", "subspecies"
    ]
    private static let statusOptions: [String] = [
        "accepted", "provisionally accepted", "synonym", "ambiguous synonym", "misapplied", "bare name"
    ]
    private static let groupOptions: [String] = [
        "viruses", "bacteria", "plants", "angiosperms", "gymnosperms", "bryophytes", "pteridophytes",
        "algae", "protists", "animals", "chordates", "arachnids", "crustacean",
        "lepidoptera", "coleoptera", "hymenoptera", "diptera", "hemiptera", "orthoptera",
        "gastropods", "ascomycetes", "basidiomycetes"
    ]

    @ViewBuilder
    private func results(vm: SearchViewModel) -> some View {
        switch vm.state {
        case .idle:
            if let group = vm.group {
                ContentUnavailableView("Filtered by group: \(group.capitalized)",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search within \(group.capitalized)."))
            } else {
                ContentUnavailableView("Search names",
                    systemImage: "magnifyingglass",
                    description: Text("Type to find taxa in \(appState.selectedDataset?.alias ?? "the selected release")."))
            }
        case .loading:
            ProgressView()
        case let .loaded(hits):
            resultsList(hits)
        case let .failed(err):
            errorView(err) { vm.submit() }
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

private struct FilterMenu: View {
    let title: String
    let value: String?       // current selection label, nil = "Any"
    let options: [String]    // available values, lowercase
    let selected: String?    // current raw value (lowercase) or nil
    let onSelect: (String?) -> Void

    var body: some View {
        Menu {
            Button {
                onSelect(nil)
            } label: {
                if selected == nil { Label("Any", systemImage: "checkmark") } else { Text("Any") }
            }
            Divider()
            ForEach(options, id: \.self) { opt in
                Button {
                    onSelect(opt)
                } label: {
                    if selected == opt {
                        Label(opt.capitalized, systemImage: "checkmark")
                    } else {
                        Text(opt.capitalized)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value ?? "Any").font(.caption)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
        }
    }
}

private struct SearchRow: View {
    let hit: SearchHit

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Reserve the icon slot even when GroupIcon resolves to nothing —
            // keeps every row's text aligned the same way.
            GroupIcon(code: hit.group, size: 22)
                .frame(width: 22, height: 22, alignment: .topLeading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hit.extinct ? "† \(hit.scientificName)" : hit.scientificName)
                        .italic().font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if hit.merged {
                        Text("XR").font(.caption2.bold())
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.purple.opacity(0.18), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                    Text(hit.rank.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                }
                if let auth = hit.authorship {
                    Text(auth).font(.caption2).foregroundStyle(.secondary)
                }
                if hit.status.isSynonym {
                    HStack(spacing: 4) {
                        Text("synonym of").font(.caption2).foregroundStyle(.orange)
                        if let accepted = hit.acceptedName {
                            Text(accepted).italic().font(.caption2).foregroundStyle(.orange)
                        } else {
                            Text("—").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
