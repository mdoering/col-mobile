import SwiftUI
import MapKit

/// Edge-to-edge GBIF density map for one taxon. Presented from
/// `GBIFSectionView` via `fullScreenCover`. Shares the same `region`
/// binding as the inline map so the user's pan/zoom transfers in both
/// directions.
struct GBIFMapFullScreenView: View {
    @Environment(AppState.self) private var appState
    let taxonId: String
    @Binding var region: MKCoordinateRegion
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GBIFMapView(
                taxonId: taxonId,
                style: appState.gbifMapStyle,
                baseStyle: appState.mapBaseStyle,
                region: $region
            )
            .ignoresSafeArea()

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
