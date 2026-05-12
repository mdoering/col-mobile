import SwiftUI

struct TaxonDetailView: View {
    @Environment(AppState.self) private var appState
    let taxonId: String
    @State private var vm: TaxonDetailViewModel?
    @State private var navigateTo: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch vm?.state {
                case .loaded(let info):
                    TaxonHeaderView(
                        info: info,
                        preferredVernacular: info.preferredVernacular(language: appState.preferredVernacularLang)
                    )
                    ClassificationChipsView(items: info.classification) { item in
                        navigateTo = item.id
                    }
                    SynonymyView(groups: info.synonymyGroups)
                    VernacularNamesView(
                        names: info.vernacularNames,
                        preferredLanguage: appState.preferredVernacularLang
                    )
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
        .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
        .navigationDestination(item: $navigateTo) { id in
            TaxonDetailView(taxonId: id)
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
}
