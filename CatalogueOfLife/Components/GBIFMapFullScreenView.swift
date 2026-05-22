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
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GBIFMapView(
                taxonId: taxonId,
                style: appState.gbifMapStyle,
                colorScheme: colorScheme,
                region: $region
            )
            .ignoresSafeArea()
            .overlay(alignment: .bottomLeading) {
                CartoAttributionLabel()
                    .padding(.leading, 12)
                    .padding(.bottom, 12)
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
}

/// Required attribution for the free Carto Positron / Dark Matter basemap tiles
/// (and the OSM data they're built from). Small, low-contrast, on a frosted chip
/// so it's legible over both light and dark Carto variants without being loud.
struct CartoAttributionLabel: View {
    var body: some View {
        Text("© OpenStreetMap, © CARTO")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .accessibilityLabel("Map tiles by Carto, data by OpenStreetMap")
    }
}
