import SwiftUI

struct SourcesView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SourcesViewModel?
    @State private var selectedSourceKey: Int?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Sources")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedSourceKey) { key in
                    SourceDetailView(sourceKey: key)
                }
        }
        .task(id: appState.selectedDataset?.key) {
            if vm == nil {
                vm = SourcesViewModel(client: APIClientLive(),
                                      getDatasetKey: { [appState] in appState.selectedDataset?.key })
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let vm {
            @Bindable var vm = vm
            switch vm.state {
            case .loaded:
                List(vm.filtered()) { source in
                    Button { selectedSourceKey = source.key } label: {
                        SourceRowView(source: source)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .searchable(text: $vm.query, prompt: "Filter sources")
            case .failed(let err):
                ContentUnavailableView("Couldn't load sources",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(String(describing: err)))
            case .idle, .loading:
                ProgressView()
            }
        } else {
            ProgressView()
        }
    }
}
