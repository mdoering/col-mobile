import Foundation

enum GBIFEndpoints {
    static let baseURL = URL(string: "https://api.gbif.org")!

    /// GBIF's unique checklist UUID for the latest Catalogue of Life release.
    /// `checklistKey` on any GBIF endpoint routes the taxon lookups through CoL.
    static let colChecklistKey = "7ddf754f-d193-4cc9-b351-99906754a03b"

    /// Default map tile style. Users can pick a different one in About → GBIF map.
    /// Polygon styles render hex-binned occurrence density (see `mapTileURLTemplate`).
    static let defaultMapTileStyle = "iNaturalist.poly"

    /// Styles exposed in the About → GBIF map → Color picker, paired with the
    /// friendly label we show in the menu. Order is preserved in the UI.
    /// All entries are polygon styles — they pair with the `bin=hex&hexPerTile=…`
    /// query that `mapTileURLTemplate` always appends (resolution chosen via
    /// the GBIF map density slider in About → Preferences).
    static let availableMapTileStyles: [(label: String, value: String)] = [
        ("iNaturalist", "iNaturalist.poly"),
        ("purple",      "purpleHeat.poly"),
        ("blue",        "blueHeat.poly"),
        ("orange",      "orangeHeat.poly"),
        ("green",       "green.poly"),
        ("classic",     "classic.poly"),
    ]

    /// `GET /v1/occurrence/search` — used for metrics (limit=0 + facets) and image fetch (mediaType=StillImage).
    static func occurrenceSearch(
        taxonId: String,
        limit: Int,
        mediaType: String? = nil,
        facets: [String] = []
    ) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "v1/occurrence/search"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "checklistKey", value: colChecklistKey),
            URLQueryItem(name: "taxonKey", value: taxonId),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let mediaType {
            items.append(URLQueryItem(name: "mediaType", value: mediaType))
        }
        for f in facets {
            items.append(URLQueryItem(name: "facet", value: f))
        }
        if !facets.isEmpty {
            items.append(URLQueryItem(name: "facetLimit", value: "300"))
        }
        c.queryItems = items
        return c.url!
    }

    /// `GET /v2/map/occurrence/density/capabilities.json?...` — returns the bounding box
    /// (minLat/maxLat/minLng/maxLng), occurrence total and year range for the taxon.
    /// Used to auto-frame the inline map on the species' actual range. `srs=EPSG:4326`
    /// means the lat/lng values come back in plain degrees.
    static func mapCapabilities(taxonId: String) -> URL {
        var c = URLComponents(
            url: baseURL.appending(path: "v2/map/occurrence/density/capabilities.json"),
            resolvingAgainstBaseURL: false
        )!
        c.queryItems = [
            URLQueryItem(name: "srs", value: "EPSG:4326"),
            URLQueryItem(name: "checklistKey", value: colChecklistKey),
            URLQueryItem(name: "taxonKey", value: taxonId),
        ]
        return c.url!
    }

    /// User-facing GBIF occurrence search URL, scoped to the COL checklist
    /// and the given taxon. Used by the "Open in GBIF" link in taxon detail
    /// and the GBIF entry in the map attribution menu.
    static func occurrenceSearchWebURL(taxonId: String) -> URL? {
        URL(string: "https://demo.gbif.org/occurrence/search?checklistKey=\(colChecklistKey)&taxonKey=\(taxonId)")
    }

    /// `GET /v2/map/occurrence/density/{z}/{x}/{y}@<resolution>.png?...` — tile template for the GBIF raster source.
    /// Notes:
    /// - The tile endpoint uses `taxonKey` (not `taxonId` as the occurrence search does).
    /// - `srs=EPSG:3857` requests Web Mercator tiles, matching MapLibre's native projection.
    ///   Without it GBIF defaults to EPSG:4326 (plate carrée) which would render misaligned.
    /// - `resolution` is the GBIF `@Nx` suffix (`"1x"` → 512×512, `"2x"` → 1024×1024).
    /// - `bin=hex&hexPerTile=<N>` renders polygon styles as hexagonal density bins,
    ///   with N hexagons across each tile (higher = finer-grained dots, slower).
    static func mapTileURLTemplate(taxonId: String, style: String = defaultMapTileStyle, resolution: String = "1x", hexPerTile: Int = 64) -> String {
        "\(baseURL.absoluteString)/v2/map/occurrence/density/{z}/{x}/{y}@\(resolution).png?srs=EPSG:3857&checklistKey=\(colChecklistKey)&taxonKey=\(taxonId)&style=\(style)&bin=hex&hexPerTile=\(hexPerTile)"
    }
}
