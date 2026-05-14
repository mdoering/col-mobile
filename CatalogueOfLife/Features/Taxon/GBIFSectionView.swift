import SwiftUI
import MapKit

struct GBIFSectionView: View {
    @Environment(AppState.self) private var appState
    let taxonId: String
    @State private var vm: GBIFSectionViewModel?
    @State private var mapFullScreen = false
    /// Single source of truth for the map's view. Initialised to the global
    /// default and overwritten once the bbox capabilities arrive; subsequent
    /// pan/zoom (in either the inline or fullscreen presenter) write back
    /// through GBIFMapView's @Binding so the two stay in sync.
    @State private var mapRegion: MKCoordinateRegion = .worldExcludingPoles
    /// Set once per taxon — guards against the bbox region overwriting a user
    /// pan if `vm.capabilities` re-publishes for any reason.
    @State private var regionSeeded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Occurrences (GBIF)").font(.headline)
            if let vm, vm.didLoad {
                if vm.failed {
                    Text("Couldn't load GBIF data for this taxon.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if hasNoGBIFData(vm) {
                    Text("No GBIF occurrence records for this taxon.")
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
            regionSeeded = false
            await vm?.load(taxonId: taxonId)
            seedRegionFromCapabilities()
        }
        .fullScreenCover(isPresented: $mapFullScreen) {
            GBIFMapFullScreenView(taxonId: taxonId, region: $mapRegion) {
                mapFullScreen = false
            }
        }
    }

    private var mapInline: some View {
        ZStack(alignment: .topTrailing) {
            GBIFMapView(
                taxonId: taxonId,
                style: appState.gbifMapStyle,
                baseStyle: appState.mapBaseStyle,
                region: $mapRegion
            )
            .frame(height: 240)
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

    /// Seed the map view from the species' bbox the first time the taxon's
    /// capabilities arrive. Subsequent pan/zoom is left untouched.
    private func seedRegionFromCapabilities() {
        guard !regionSeeded else { return }
        if let caps = vm?.capabilities, let region = MKCoordinateRegion(capabilities: caps) {
            mapRegion = region
        } else {
            mapRegion = .worldExcludingPoles
        }
        regionSeeded = true
    }

    /// True when both the occurrence count and the image list are empty —
    /// i.e. GBIF responded successfully but has nothing for this taxon.
    private func hasNoGBIFData(_ vm: GBIFSectionViewModel) -> Bool {
        let zeroCount = (vm.metrics?.occurrenceCount ?? 0) == 0
        let zeroCaps = (vm.capabilities?.total ?? 0) == 0
        return zeroCount && vm.images.isEmpty && zeroCaps
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
                .map { "\($0.code) (\(Self.compactCount($0.count)))" }
                .joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.compactCount(value))
                .font(.title3.monospacedDigit().bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "1,234" → "1.2k", "4,500,000" → "4.5m", anything below 1000 stays as-is.
    /// Lower-cased so 1.2k/4.5m/1b read more compactly than the locale's
    /// default `K/M/B` suffix and stay on a single line under the metric label.
    static func compactCount(_ value: Int) -> String {
        if abs(value) < 1000 {
            return value.formatted(.number.grouping(.never))
        }
        let formatted = value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        return formatted.lowercased()
    }
}
