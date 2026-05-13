import Foundation

enum GBIFEndpoints {
    static let baseURL = URL(string: "https://api.gbif.org")!

    /// GBIF's unique checklist UUID for the latest Catalogue of Life release.
    /// `checklistKey` on any GBIF endpoint routes the taxon lookups through CoL.
    static let colChecklistKey = "7ddf754f-d193-4cc9-b351-99906754a03b"

    /// Default map tile style. Users can pick a different one in About → GBIF map.
    static let defaultMapTileStyle = "purpleHeat.point"

    /// Styles exposed in the About → GBIF map → Color picker, paired with the
    /// friendly label we show in the menu. Order is preserved in the UI.
    static let availableMapTileStyles: [(label: String, value: String)] = [
        ("pink",   "purpleHeat.point"),
        ("blue",   "blueHeat.point"),
        ("orange", "orangeHeat.point"),
        ("red",    "red.poly"),
        ("yellow", "classic.point"),
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

    /// `GET /v2/map/occurrence/density/{z}/{x}/{y}@<resolution>.png?...` — tile template for `MKTileOverlay`.
    /// Notes:
    /// - The tile endpoint uses `taxonKey` (not `taxonId` as the occurrence search does).
    /// - `srs=EPSG:3857` requests Web Mercator tiles, matching `MKMapView`'s native projection.
    ///   Without it GBIF defaults to EPSG:4326 (plate carrée) which would render misaligned.
    /// - `resolution` is the GBIF `@Nx` suffix (`"1x"` → 512×512, `"2x"` → 1024×1024).
    static func mapTileURLTemplate(taxonId: String, style: String = defaultMapTileStyle, resolution: String = "1x") -> String {
        "\(baseURL.absoluteString)/v2/map/occurrence/density/{z}/{x}/{y}@\(resolution).png?srs=EPSG:3857&checklistKey=\(colChecklistKey)&taxonKey=\(taxonId)&style=\(style)"
    }
}
