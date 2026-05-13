import SwiftUI

struct GBIFSectionView: View {
    @Environment(AppState.self) private var appState
    let taxonId: String
    @State private var vm: GBIFSectionViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Occurrences (GBIF)").font(.headline)
            if let vm, vm.didLoad {
                if vm.failed {
                    Text("Couldn't load GBIF data for this taxon.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    GBIFMapView(taxonId: taxonId, style: appState.gbifMapStyle)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    if let m = vm.metrics { metricsRow(m) }
                    GBIFImageCarouselView(items: vm.images)
                }
            } else {
                ProgressView()
            }
        }
        .task(id: taxonId) {
            if vm == nil {
                vm = GBIFSectionViewModel(client: GBIFClientLive())
            }
            await vm?.load(taxonId: taxonId)
        }
    }

    @ViewBuilder
    private func metricsRow(_ m: GBIFMetrics) -> some View {
        HStack(spacing: 16) {
            metric("Occurrences", m.occurrenceCount)
            metric("Countries", m.distinctCountries)
            metric("Datasets", m.distinctDatasets)
        }
        if !m.topCountries.isEmpty {
            Text("Top countries: " + m.topCountries
                .map { "\($0.code) (\($0.count.formatted(.number)))" }
                .joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title3.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
