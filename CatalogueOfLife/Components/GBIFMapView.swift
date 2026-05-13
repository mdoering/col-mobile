import SwiftUI
import MapKit

/// SwiftUI wrapper for an MKMapView that displays GBIF density tiles
/// for one COL taxon (gated upstream by `AppState.gbifAvailable`).
struct GBIFMapView: UIViewRepresentable {
    let taxonId: String
    let style: String
    /// GBIF tile resolution: "1x" (512×512) or "2x" (1024×1024).
    var resolution: String = "1x"
    /// Apple base-map style: "standard", "standardMuted", "hybrid", "imagery".
    var baseStyle: String = "standard"
    /// Elevation style: "flat" or "realistic".
    var elevation: String = "flat"

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = mapConfiguration()
        let overlay = GBIFTileOverlay(taxonId: taxonId, style: style, resolution: resolution)
        map.addOverlay(overlay, level: .aboveLabels)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let existing = uiView.overlays.compactMap { $0 as? GBIFTileOverlay }
        if existing.first?.taxonId != taxonId
            || existing.first?.style != style
            || existing.first?.resolution != resolution
        {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlay(GBIFTileOverlay(taxonId: taxonId, style: style, resolution: resolution), level: .aboveLabels)
        }
        uiView.preferredConfiguration = mapConfiguration()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tile = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            return MKTileOverlayRenderer(tileOverlay: tile)
        }
    }

    private func mapConfiguration() -> MKMapConfiguration {
        let elev: MKMapConfiguration.ElevationStyle = (elevation == "realistic") ? .realistic : .flat
        switch baseStyle {
        case "hybrid":
            return MKHybridMapConfiguration(elevationStyle: elev)
        case "imagery":
            return MKImageryMapConfiguration(elevationStyle: elev)
        case "standardMuted":
            return MKStandardMapConfiguration(elevationStyle: elev, emphasisStyle: .muted)
        default:
            return MKStandardMapConfiguration(elevationStyle: elev, emphasisStyle: .default)
        }
    }
}

/// MKTileOverlay subclass that requests GBIF density tiles for the COL checklist + given taxon + chosen style.
final class GBIFTileOverlay: MKTileOverlay, @unchecked Sendable {
    let taxonId: String
    let style: String
    let resolution: String

    init(taxonId: String, style: String, resolution: String = "1x") {
        self.taxonId = taxonId
        self.style = style
        self.resolution = resolution
        super.init(urlTemplate: GBIFEndpoints.mapTileURLTemplate(taxonId: taxonId, style: style, resolution: resolution))
        self.canReplaceMapContent = false
        self.minimumZ = 0
        self.maximumZ = 12
        // Match the GBIF tile pixel size to MKTileOverlay's tileSize. "1x" = 512px source,
        // which renders crisply on 2x retina screens at the default 256pt tile. "2x" = 1024px,
        // crisper on 3x screens but ~4× the bytes.
    }
}
