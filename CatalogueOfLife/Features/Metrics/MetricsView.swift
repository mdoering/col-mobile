import SwiftUI

struct MetricsView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: MetricsViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Metrics")
        }
        .task(id: appState.selectedDataset?.key) {
            if vm == nil {
                vm = MetricsViewModel(client: APIClientLive(),
                                       getDatasetKey: { [appState] in appState.selectedDataset?.key })
            }
            await vm?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm?.state {
        case .loaded(let breakdown, let metrics):
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Taxonomic breakdown")
                        .font(.headline)
                    SunburstView(root: SunburstNode.from(breakdown: breakdown))
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                    if let metrics {
                        ImportMetricsList(metrics: metrics)
                    }
                }
                .padding()
            }
        case .failed(let err):
            ContentUnavailableView("Couldn't load metrics",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text(String(describing: err)))
        case .loading, .idle, .none:
            ProgressView()
        }
    }
}
