import SwiftUI
import MapKit

/// SwiftUI wrapper for an MKMapView that displays GBIF density tiles
/// for one COL taxon (gated upstream by `AppState.gbifAvailable`).
struct GBIFMapView: UIViewRepresentable {
    let taxonId: String
    let style: String

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        let overlay = GBIFTileOverlay(taxonId: taxonId, style: style)
        map.addOverlay(overlay, level: .aboveLabels)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Replace overlay if taxonId OR style changed (push to new taxon, or settings change).
        let existing = uiView.overlays.compactMap { $0 as? GBIFTileOverlay }
        if existing.first?.taxonId != taxonId || existing.first?.style != style {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlay(GBIFTileOverlay(taxonId: taxonId, style: style), level: .aboveLabels)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tile = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            return MKTileOverlayRenderer(tileOverlay: tile)
        }
    }
}

/// MKTileOverlay subclass that requests GBIF density tiles for the COL checklist + given taxon + chosen style.
final class GBIFTileOverlay: MKTileOverlay, @unchecked Sendable {
    let taxonId: String
    let style: String

    init(taxonId: String, style: String) {
        self.taxonId = taxonId
        self.style = style
        super.init(urlTemplate: GBIFEndpoints.mapTileURLTemplate(taxonId: taxonId, style: style))
        self.canReplaceMapContent = false
        self.minimumZ = 0
        self.maximumZ = 12
    }
}
