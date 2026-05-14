import SwiftUI
import MapKit

/// SwiftUI wrapper for an MKMapView that displays GBIF density tiles
/// for one COL taxon. (CoL identifiers have been stable since COL21,
/// so every release we expose resolves through GBIF's COL checklist.)
struct GBIFMapView: UIViewRepresentable {
    let taxonId: String
    let style: String
    /// Apple base-map style: "standard", "standardMuted", "hybrid", "imagery".
    var baseStyle: String = "hybrid"
    /// 0.0…1.0 — Apple base map opacity. 1.0 = no dimming. Lower values
    /// fade Apple's base map (and its labels) toward the system background
    /// without touching the GBIF density tiles, which sit on top.
    var baseMapOpacity: Double = 1.0
    /// Two-way region binding. The owning view drives the initial framing and
    /// receives the user's pan/zoom changes, so the inline map and the
    /// fullscreen presentation share the same view-state.
    @Binding var region: MKCoordinateRegion

    /// GBIF tile resolution is fixed to "1x" (512×512). "2x" doubled bandwidth
    /// for a marginal visual difference at typical zoom levels.
    private let resolution = "1x"

    func makeUIView(context: Context) -> MKMapView {
        context.coordinator.parent = self
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = mapConfiguration()
        // Order matters within a level: the dim sheet is added first, so the
        // GBIF tiles end up rendered on top of it (and on top of Apple's
        // base map + labels, which the dim sheet sits over).
        map.addOverlay(BaseMapDimOverlay(), level: .aboveLabels)
        map.addOverlay(GBIFTileOverlay(taxonId: taxonId, style: style, resolution: resolution), level: .aboveLabels)
        context.coordinator.applyProgrammatically(region, to: map)
        context.coordinator.lastAppliedTaxonId = taxonId
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self
        let existing = uiView.overlays.compactMap { $0 as? GBIFTileOverlay }
        let taxonChanged = existing.first?.taxonId != taxonId
        if taxonChanged
            || existing.first?.style != style
            || existing.first?.resolution != resolution
        {
            // Drop everything and re-add both layers in the right order so
            // the dim sheet stays under the GBIF tiles.
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlay(BaseMapDimOverlay(), level: .aboveLabels)
            uiView.addOverlay(GBIFTileOverlay(taxonId: taxonId, style: style, resolution: resolution), level: .aboveLabels)
        }
        // Update the dim renderer in place — no need to swap the overlay.
        if let dim = uiView.overlays.first(where: { $0 is BaseMapDimOverlay }),
           let renderer = uiView.renderer(for: dim) as? BaseMapDimRenderer {
            let newOpacity = CGFloat(baseMapOpacity)
            if renderer.baseMapOpacity != newOpacity {
                renderer.baseMapOpacity = newOpacity
                renderer.setNeedsDisplay()
            }
        }
        uiView.preferredConfiguration = mapConfiguration()
        // Apply the binding's region whenever it diverges noticeably from the
        // map's current view (e.g. fullscreen was just dismissed) or when the
        // taxon itself changed. We never override during a user gesture: the
        // delegate's region-change callback skips itself while we're inside
        // applyProgrammatically, so this branch can't trigger a feedback loop.
        if taxonChanged || !regionsApproximatelyEqual(uiView.region, region) {
            context.coordinator.applyProgrammatically(region, to: uiView)
            context.coordinator.lastAppliedTaxonId = taxonId
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GBIFMapView?
        /// Tracks which taxon's region we last applied so AppState-driven
        /// updateUIView calls don't clobber the user's pan/zoom.
        var lastAppliedTaxonId: String?
        /// True while we're setting the region ourselves — used to suppress
        /// the delegate's write-back so the parent binding doesn't oscillate.
        private var isProgrammaticUpdate = false

        func applyProgrammatically(_ region: MKCoordinateRegion, to map: MKMapView) {
            // Setting an out-of-range region crashes MapKit. The init?(capabilities:)
            // path already redirects bad GBIF bboxes to worldExcludingPoles, but
            // also guard here in case a bound binding update slips one through.
            let safe = region.isValidForMap ? region : .worldExcludingPoles
            isProgrammaticUpdate = true
            map.setRegion(safe, animated: false)
            isProgrammaticUpdate = false
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let dim = overlay as? BaseMapDimOverlay {
                let renderer = BaseMapDimRenderer(overlay: dim)
                renderer.baseMapOpacity = CGFloat(parent?.baseMapOpacity ?? 1.0)
                return renderer
            }
            guard let tile = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            return MKTileOverlayRenderer(tileOverlay: tile)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !isProgrammaticUpdate, let parent else { return }
            parent.region = mapView.region
        }
    }

    private func mapConfiguration() -> MKMapConfiguration {
        // Elevation is always flat — realistic 3-D adds a lot of CPU/GPU work
        // without buying clarity for occurrence-density overlays.
        let elev: MKMapConfiguration.ElevationStyle = .flat
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
    /// the species' bounding box covers most of the planet (or isn't known yet).
    /// Centered at 25°N, where most biodiversity occurrence records cluster
    /// (Europe + North America + temperate Asia), rather than (0, 0) which
    /// puts the Atlantic-off-Africa front and centre.
    static let worldExcludingPoles = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25, longitude: 10),
        span: MKCoordinateSpan(latitudeDelta: 130, longitudeDelta: 340)
    )

    /// Inset region around the species' GBIF occurrence bounding box, with 40%
    /// padding and a 6° minimum span so single-country ranges don't render
    /// too tightly.
    ///
    /// Falls back to `worldExcludingPoles` for taxa whose range is effectively
    /// global — a bbox of (-90..90, -180..180) centres at (0, 0) and visually
    /// suggests the species lives only in Africa, which is misleading. Once
    /// the span exceeds ~⅔ of the world in either dimension, the species is
    /// best framed by the standard world view.
    init?(capabilities: GBIFMapCapabilities) {
        guard capabilities.hasData else { return nil }
        let rawLatSpan = capabilities.maxLat - capabilities.minLat
        let rawLngSpan = capabilities.maxLng - capabilities.minLng
        if rawLatSpan > 120 || rawLngSpan > 240 {
            self = .worldExcludingPoles
            return
        }
        // GBIF occasionally reports a bbox that wraps across the antimeridian
        // by extending beyond ±180 (e.g. minLng=94, maxLng=291 for a Pacific
        // species). MKCoordinateRegion validates the centre to [-180, 180]
        // and crashes hard with NSInvalidArgumentException otherwise — so
        // bail to the world view rather than feed it an out-of-range value.
        guard capabilities.minLng >= -180, capabilities.maxLng <= 180,
              capabilities.minLat >= -90, capabilities.maxLat <= 90 else {
            self = .worldExcludingPoles
            return
        }
        let minLat = max(capabilities.minLat, -85)
        let maxLat = min(capabilities.maxLat, 85)
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (capabilities.minLng + capabilities.maxLng) / 2
        let latDelta = max(maxLat - minLat, 6) * 1.4
        let lonDelta = max(rawLngSpan, 6) * 1.4
        self.init(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(
                latitudeDelta: min(latDelta, 160),
                longitudeDelta: min(lonDelta, 340)
            )
        )
    }

    /// Lightweight defensive check used before calling `setRegion(_:)` —
    /// returns false for a region whose centre or span lies outside MapKit's
    /// accepted bounds, which would otherwise throw NSInvalidArgumentException.
    var isValidForMap: Bool {
        let lat = center.latitude
        let lng = center.longitude
        let dLat = span.latitudeDelta
        let dLng = span.longitudeDelta
        return lat.isFinite && lng.isFinite && dLat.isFinite && dLng.isFinite
            && lat >= -90 && lat <= 90
            && lng >= -180 && lng <= 180
            && dLat >= 0 && dLat <= 180
            && dLng >= 0 && dLng <= 360
    }
}

/// Centre + span equality with a small epsilon — used to decide whether the
/// SwiftUI binding's region has drifted from the live MKMapView region enough
/// to need a re-apply (e.g. after the fullscreen presenter dismissed).
private func regionsApproximatelyEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
    let eps = 0.0005
    return abs(a.center.latitude - b.center.latitude) < eps
        && abs(a.center.longitude - b.center.longitude) < eps
        && abs(a.span.latitudeDelta - b.span.latitudeDelta) < eps
        && abs(a.span.longitudeDelta - b.span.longitudeDelta) < eps
}

/// World-spanning marker overlay rendered as a single semi-transparent
/// system-background fill above Apple's base map and labels but below the
/// GBIF density tiles — fades the base map without dimming the dots.
final class BaseMapDimOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    override init() {
        self.boundingMapRect = .world
        let mid = MKMapPoint(x: MKMapRect.world.midX, y: MKMapRect.world.midY)
        self.coordinate = mid.coordinate
        super.init()
    }
}

/// Fills its bounds with `systemBackground.withAlphaComponent(1 - opacity)`.
/// `systemBackground` (white in light mode, near-black in dark mode) keeps
/// the dim from looking like a glaring white wash on dark themes.
final class BaseMapDimRenderer: MKOverlayRenderer {
    var baseMapOpacity: CGFloat = 1.0

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let alpha = max(0, min(1, 1 - baseMapOpacity))
        guard alpha > 0 else { return }
        context.setFillColor(UIColor.systemBackground.withAlphaComponent(alpha).cgColor)
        context.fill(rect(for: mapRect))
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
