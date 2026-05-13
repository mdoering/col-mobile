import SwiftUI

struct MetricsView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: MetricsViewModel?
    @State private var timeline: [ReleaseTimelineEntry] = ReleaseTimeline.loadBundled()
    @State private var fullScreenSunburst: SunburstNode?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Metrics")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: appState.selectedDataset?.key) {
            if vm == nil {
                vm = MetricsViewModel(client: APIClientLive(),
                                       getDatasetKey: { [appState] in appState.selectedDataset?.key })
            }
            await vm?.load()
        }
        .fullScreenCover(item: $fullScreenSunburst) { root in
            SunburstFullScreenView(
                root: root,
                maxDepth: 2,
                popoverKind: .group
            ) { node in
                appState.pendingSearchGroup = node.label
                appState.selectedTabIndex = 1
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm?.state {
        case .loaded(let breakdown, let metrics):
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ReleaseTimelineChart(entries: timeline)
                    if let metrics {
                        ImportMetricsList(metrics: metrics, includeSummary: true, includeSections: false)
                    }
                    let breakdownRoot = SunburstNode.from(breakdown: breakdown)
                    HStack {
                        Text("Taxonomic breakdown").font(.headline)
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
                        popoverKind: .group
                    ) { node in
                        appState.pendingSearchGroup = node.label
                        appState.selectedTabIndex = 1
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    if let metrics {
                        ImportMetricsList(metrics: metrics, includeSummary: false, includeSections: true)
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
