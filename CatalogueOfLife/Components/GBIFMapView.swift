import SwiftUI
import MapKit
import MapLibre

/// SwiftUI wrapper for an MLNMapView that renders Carto's Positron (light)
/// or Dark Matter (dark) vector basemap with GBIF occurrence-density raster
/// tiles for one COL taxon overlaid on top. (CoL identifiers have been
/// stable since COL21, so every release we expose resolves through GBIF's
/// COL checklist.)
///
/// The `MKCoordinateRegion` binding is kept at the public interface so
/// `GBIFSectionView` / `GBIFMapFullScreenView` continue to use familiar
/// MapKit types. Internally we translate to/from `MLNCoordinateBounds`.
struct GBIFMapView: UIViewRepresentable {
    let taxonId: String
    let style: String
    /// Number of hexagonal bins per tile in the GBIF density request (the
    /// `hexPerTile` query parameter). Pinned to AppState.gbifHexPerTile.
    var hexPerTile: Int = 64
    var colorScheme: ColorScheme = .light
    @Binding var region: MKCoordinateRegion
    /// Owned by the parent SwiftUI view. We push the basemap's URL-bearing
    /// attribution items into it whenever the style finishes loading; the
    /// parent overlays a Menu-backed (i) button reading from it. Optional so
    /// the few tests / previews that don't care can skip wiring it.
    var attribution: MapAttributionState? = nil

    /// GBIF tile resolution. "1x" → 512px source PNG, which renders crisply
    /// at the 512-pt tile size we request from the MapLibre raster source.
    private let resolution = "1x"
    private static let gbifSourceID = "gbif-density"
    private static let gbifLayerID = "gbif-density-layer"

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: Self.styleURL(for: colorScheme))
        map.delegate = context.coordinator
        // Hide MapLibre's built-in chrome:
        // - logoView: small MapLibre wordmark, confusing alongside Carto's brand.
        // - compassView: rotation is disabled, so the compass never appears anyway.
        // - attributionButton: Carto publishes "©" and "contributors" outside
        //   their <a> tags, which MapLibre then renders as dead tap targets.
        //   The Coordinator instead pushes the source's URL-bearing infos to
        //   `attribution`, which `GBIFSectionView` / `GBIFMapFullScreenView`
        //   present via a Menu-backed SwiftUI (i) button.
        map.logoView.isHidden = true
        map.compassView.isHidden = true
        map.attributionButton.isHidden = true
        map.allowsRotating = false
        map.allowsTilting = false
        // Hide the floating "Track user location" button — we don't request
        // location and the empty button would otherwise sit on the map corner.
        map.showsUserLocation = false
        context.coordinator.parent = self
        context.coordinator.apply(region: region, to: map, animated: false)
        context.coordinator.lastAppliedTaxonId = taxonId
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.parent = self
        let wantedStyleURL = Self.styleURL(for: colorScheme)
        let styleChanged = map.styleURL != wantedStyleURL
        let taxonChanged = context.coordinator.lastAppliedTaxonId != taxonId
        let gbifStyleChanged = context.coordinator.lastAppliedGBIFStyle != style
        let hexPerTileChanged = context.coordinator.lastAppliedHexPerTile != hexPerTile

        if styleChanged {
            // Swapping styleURL triggers a full reload; the delegate's
            // didFinishLoading callback re-attaches the GBIF source/layer.
            map.styleURL = wantedStyleURL
        } else if taxonChanged || gbifStyleChanged || hexPerTileChanged {
            context.coordinator.refreshGBIFLayer(on: map)
        }

        if taxonChanged || !context.coordinator.regionsApproximatelyEqual(map.regionAsMKRegion, region) {
            context.coordinator.apply(region: region, to: map, animated: false)
            context.coordinator.lastAppliedTaxonId = taxonId
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: GBIFMapView?
        /// Tracks which taxon's region we last applied so updateUIView calls
        /// from upstream state changes don't clobber the user's pan/zoom.
        fileprivate(set) var lastAppliedTaxonId: String?
        fileprivate(set) var lastAppliedGBIFStyle: String?
        fileprivate(set) var lastAppliedHexPerTile: Int?
        private var isProgrammaticUpdate = false

        /// Called every time the basemap style finishes loading — including
        /// after a light↔dark swap, which wipes any custom sources/layers.
        /// (Re)adds the GBIF raster source on top of the labels layer and
        /// republishes the basemap's URL-bearing attribution items.
        ///
        /// MapLibre's Obj-C delegate is nonisolated, but UIKit guarantees these
        /// callbacks arrive on the main thread; `MainActor.assumeIsolated`
        /// lets us hop back into the actor without an unnecessary `Task`.
        nonisolated func mapView(_ map: MLNMapView, didFinishLoading style: MLNStyle) {
            MainActor.assumeIsolated {
                refreshGBIFLayer(on: map)
                // Read the style off `map` inside the main-actor block — the
                // delegate's `style` parameter is non-Sendable and the
                // compiler can't prove it's safe to ferry across the hop.
                if let mapStyle = map.style {
                    refreshAttribution(from: mapStyle)
                }
            }
        }

        /// Collect attribution items from every tile source in the style,
        /// keep only those with a non-nil URL (Carto's "©" and "contributors"
        /// rows have no URL — they're outside the `<a>` tags upstream), dedupe
        /// by destination URL, and hand them to the parent's state object.
        func refreshAttribution(from style: MLNStyle) {
            guard let target = parent?.attribution else { return }
            var seen = Set<URL>()
            var links: [MapAttributionLink] = []
            for source in style.sources {
                guard let tileSource = source as? MLNTileSource else { continue }
                for info in tileSource.attributionInfos {
                    guard let url = info.url, seen.insert(url).inserted else { continue }
                    links.append(MapAttributionLink(title: info.title.string, url: url))
                }
            }
            target.links = links
        }

        /// Tear down any previous GBIF layer/source and add a fresh one
        /// pointing at the current taxon + style.
        func refreshGBIFLayer(on map: MLNMapView) {
            guard let parent, let style = map.style else { return }
            if let existing = style.layer(withIdentifier: GBIFMapView.gbifLayerID) {
                style.removeLayer(existing)
            }
            if let existing = style.source(withIdentifier: GBIFMapView.gbifSourceID) {
                style.removeSource(existing)
            }

            let template = GBIFEndpoints.mapTileURLTemplate(
                taxonId: parent.taxonId,
                style: parent.style,
                resolution: parent.resolution,
                hexPerTile: parent.hexPerTile
            )
            // 512-pt tile size matches the GBIF "1x" tile pixel size and
            // gives crisp rendering on retina iPhones; raster max-zoom is
            // capped at the GBIF endpoint's max (12).
            let source = MLNRasterTileSource(
                identifier: GBIFMapView.gbifSourceID,
                tileURLTemplates: [template],
                options: [
                    .minimumZoomLevel: 0,
                    .maximumZoomLevel: 12,
                    .tileSize: 512,
                ]
            )
            let layer = MLNRasterStyleLayer(identifier: GBIFMapView.gbifLayerID, source: source)
            style.addSource(source)
            style.addLayer(layer)
            lastAppliedGBIFStyle = parent.style
            lastAppliedHexPerTile = parent.hexPerTile
        }

        func apply(region: MKCoordinateRegion, to map: MLNMapView, animated: Bool) {
            let safe = region.isValidForMap ? region : .worldExcludingPoles
            let halfLat = safe.span.latitudeDelta / 2
            let halfLng = safe.span.longitudeDelta / 2
            let bounds = MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: safe.center.latitude - halfLat,
                                           longitude: safe.center.longitude - halfLng),
                ne: CLLocationCoordinate2D(latitude: safe.center.latitude + halfLat,
                                           longitude: safe.center.longitude + halfLng)
            )
            isProgrammaticUpdate = true
            map.setVisibleCoordinateBounds(bounds, animated: animated)
            isProgrammaticUpdate = false
        }

        nonisolated func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            MainActor.assumeIsolated {
                guard !isProgrammaticUpdate, let parent else { return }
                parent.region = mapView.regionAsMKRegion
            }
        }

        fileprivate func regionsApproximatelyEqual(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
            let eps = 0.0005
            return abs(a.center.latitude - b.center.latitude) < eps
                && abs(a.center.longitude - b.center.longitude) < eps
                && abs(a.span.latitudeDelta - b.span.latitudeDelta) < eps
                && abs(a.span.longitudeDelta - b.span.longitudeDelta) < eps
        }
    }

    /// Public Carto GL JSON styles. Switched live by the SwiftUI color scheme.
    /// (Tile access via basemaps.cartocdn.com is technically restricted to
    /// Carto enterprise customers and grant recipients — see project memory.)
    private static func styleURL(for scheme: ColorScheme) -> URL {
        URL(string: scheme == .dark
            ? "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json"
            : "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json")!
    }
}

/// A single attribution row: the link text Carto/OSM publish for their tiles,
/// paired with the URL it should open. Title and URL are taken verbatim from
/// `MLNAttributionInfo`, so anything Carto adds upstream flows through.
struct MapAttributionLink: Identifiable, Hashable, Sendable {
    let title: String
    let url: URL
    var id: URL { url }
}

/// Bridge between MapLibre's source list (which is populated asynchronously
/// once the style loads) and SwiftUI. The map's Coordinator writes into
/// `links`; the SwiftUI parent reads it back to render the (i) menu.
@MainActor
@Observable
final class MapAttributionState {
    var links: [MapAttributionLink] = []
}

/// (i) button that drops down a Menu of working attribution links. Styled to
/// match the inline map's "expand" affordance. Renders nothing until at least
/// one URL-bearing attribution arrives — avoids a button with an empty menu
/// while the basemap style is still loading.
///
/// `extras` are static, caller-supplied entries shown above the basemap items
/// — used by `GBIFSectionView` to point at the taxon-scoped GBIF occurrence
/// search, since the density tiles drawn on top of the basemap come from GBIF.
struct MapAttributionButton: View {
    var extras: [MapAttributionLink] = []
    let links: [MapAttributionLink]

    var body: some View {
        let all = extras + links
        if all.isEmpty {
            EmptyView()
        } else {
            Menu {
                ForEach(all) { link in
                    Link(link.title, destination: link.url)
                }
            } label: {
                Image(systemName: "info.circle")
                    .font(.callout.weight(.semibold))
                    .padding(7)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Map attribution")
        }
    }
}

extension MLNMapView {
    /// MapLibre's `visibleCoordinateBounds` is a sw/ne rectangle. Convert it
    /// into the MapKit center+span form that the rest of the app uses for
    /// region bindings.
    var regionAsMKRegion: MKCoordinateRegion {
        let b = visibleCoordinateBounds
        let center = CLLocationCoordinate2D(
            latitude: (b.sw.latitude + b.ne.latitude) / 2,
            longitude: (b.sw.longitude + b.ne.longitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(b.ne.latitude - b.sw.latitude, 0),
            longitudeDelta: max(b.ne.longitude - b.sw.longitude, 0)
        )
        return MKCoordinateRegion(center: center, span: span)
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

    /// Lightweight defensive check used before applying the region — returns
    /// false for centres or spans outside the valid lat/lng ranges.
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
