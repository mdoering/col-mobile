import SwiftUI
import MapKit

struct GBIFSectionView: View {
    @Environment(AppState.self) private var appState
    let taxonId: String
    @State private var vm: GBIFSectionViewModel?
    @State private var mapFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Occurrences (GBIF)").font(.headline)
            if let vm, vm.didLoad {
                if vm.failed {
                    Text("Couldn't load GBIF data for this taxon.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    mapInline
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
        .fullScreenCover(isPresented: $mapFullScreen) {
            GBIFMapFullScreenView(taxonId: taxonId) { mapFullScreen = false }
        }
    }

    private var mapInline: some View {
        ZStack(alignment: .topTrailing) {
            GBIFMapView(
                taxonId: taxonId,
                style: appState.gbifMapStyle,
                baseStyle: appState.mapBaseStyle,
                initialRegion: inlineMapRegion
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                mapFullScreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.callout.weight(.semibold))
                    .padding(7)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Expand map")
            .padding(8)
        }
    }

    /// Frame the species' actual range when GBIF capabilities are available;
    /// otherwise fall back to a global view minus the poles.
    private var inlineMapRegion: MKCoordinateRegion {
        if let caps = vm?.capabilities, let region = MKCoordinateRegion(capabilities: caps) {
            return region
        }
        return .worldExcludingPoles
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
