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
    /// Initial region to frame. Nil = leave at MKMapView's default. The region is
    /// applied once on creation and re-applied if the taxon (and therefore the
    /// region) changes, so the user can still pan/zoom afterwards.
    var initialRegion: MKCoordinateRegion?

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
        if let r = initialRegion {
            map.setRegion(r, animated: false)
        }
        context.coordinator.lastAppliedTaxonId = taxonId
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let existing = uiView.overlays.compactMap { $0 as? GBIFTileOverlay }
        let taxonChanged = existing.first?.taxonId != taxonId
        if taxonChanged
            || existing.first?.style != style
            || existing.first?.resolution != resolution
        {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlay(GBIFTileOverlay(taxonId: taxonId, style: style, resolution: resolution), level: .aboveLabels)
        }
        uiView.preferredConfiguration = mapConfiguration()
        // Re-apply the region only when the taxon changes — otherwise the user's
        // pan/zoom would be reset every time AppState publishes (style, etc.).
        if taxonChanged, let r = initialRegion {
            uiView.setRegion(r, animated: false)
            context.coordinator.lastAppliedTaxonId = taxonId
        } else if context.coordinator.lastAppliedTaxonId != taxonId, let r = initialRegion {
            uiView.setRegion(r, animated: false)
            context.coordinator.lastAppliedTaxonId = taxonId
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        /// Tracks which taxon's region we last applied so AppState-driven
        /// updateUIView calls don't clobber the user's pan/zoom.
        var lastAppliedTaxonId: String?

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

extension MKCoordinateRegion {
    /// World view minus the polar regions — used as the inline-map default when
    /// the species' bounding box isn't known yet (or has zero occurrences).
    static let worldExcludingPoles = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 15, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 130, longitudeDelta: 340)
    )

    /// Inset region around the species' GBIF occurrence bounding box, with 30%
    /// padding and a 6° minimum span so single-country ranges don't render
    /// too tightly. Returns nil if the taxon has no occurrence records.
    init?(capabilities: GBIFMapCapabilities) {
        guard capabilities.hasData else { return nil }
        let minLat = max(capabilities.minLat, -85)
        let maxLat = min(capabilities.maxLat, 85)
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (capabilities.minLng + capabilities.maxLng) / 2
        let latDelta = max(maxLat - minLat, 6) * 1.3
        let lonDelta = max(capabilities.maxLng - capabilities.minLng, 6) * 1.3
        self.init(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(
                latitudeDelta: min(latDelta, 160),
                longitudeDelta: min(lonDelta, 340)
            )
        )
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
