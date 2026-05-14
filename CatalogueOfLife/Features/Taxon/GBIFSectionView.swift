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
                baseMapOpacity: appState.baseMapOpacity,
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

    /// "1,234" → "1.2k", "4,500,000" → "4.5M", "1,000,000,000" → "1B".
    /// Anything below 1000 stays as a plain integer with no grouping.
    ///
    /// Built by hand rather than via `.notation(.compactName)` because the
    /// locale-aware compact notation translates the unit (German "Mio.",
    /// French "Md", etc.) — too wide to keep the metric on a single line
    /// under its label. The leading number still follows the user's locale
    /// separator so 1.2k vs 1,2k matches the rest of the UI.
    static func compactCount(_ value: Int) -> String {
        let absVal = abs(value)
        let sign = value < 0 ? "-" : ""
        if absVal < 1000 {
            return "\(sign)\(absVal)"
        }
        let (scaled, suffix): (Double, String)
        if absVal < 1_000_000 {
            scaled = Double(absVal) / 1_000
            suffix = "k"
        } else if absVal < 1_000_000_000 {
            scaled = Double(absVal) / 1_000_000
            suffix = "M"
        } else {
            scaled = Double(absVal) / 1_000_000_000
            suffix = "B"
        }
        let formatted = scaled.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
        return "\(sign)\(formatted)\(suffix)"
    }
}
