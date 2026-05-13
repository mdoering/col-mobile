import SwiftUI

/// Edge-to-edge GBIF density map for one taxon. Presented from
/// `GBIFSectionView` via `fullScreenCover`.
struct GBIFMapFullScreenView: View {
    @Environment(AppState.self) private var appState
    let taxonId: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GBIFMapView(
                taxonId: taxonId,
                style: appState.gbifMapStyle,
                baseStyle: appState.mapBaseStyle
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
