import SwiftUI
import MapKit

/// Edge-to-edge GBIF density map for one taxon. Presented from
/// `GBIFSectionView` via `fullScreenCover`. Shares the same `region`
/// binding as the inline map so the user's pan/zoom transfers in both
/// directions.
struct GBIFMapFullScreenView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let taxonId: String
    @Binding var region: MKCoordinateRegion
    /// Shared with the inline `GBIFSectionView` so the attribution items
    /// stay in sync as the map style reloads in either presentation.
    let attribution: MapAttributionState
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GBIFMapView(
                taxonId: taxonId,
                style: appState.gbifMapStyle,
                hexPerTile: appState.gbifHexPerTile,
                colorScheme: colorScheme,
                region: $region,
                attribution: attribution
            )
            .ignoresSafeArea()
            .overlay(alignment: .bottomTrailing) {
                MapAttributionButton(extras: gbifExtras, links: attribution.links)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .accessibilityLabel("Close map")
            .padding()
        }
    }

    /// Same per-taxon GBIF occurrence search link the inline section uses
    /// — duplicated here because the fullscreen presenter is its own root
    /// view and doesn't see GBIFSectionView's helper directly.
    private var gbifExtras: [MapAttributionLink] {
        guard let url = GBIFEndpoints.occurrenceSearchWebURL(taxonId: taxonId) else { return [] }
        return [MapAttributionLink(title: "GBIF", url: url)]
    }
}
