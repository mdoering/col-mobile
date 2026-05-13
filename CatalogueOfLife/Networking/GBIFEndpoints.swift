import Foundation

enum GBIFEndpoints {
    static let baseURL = URL(string: "https://api.gbif.org")!

    /// GBIF's unique checklist UUID for the latest Catalogue of Life release.
    /// `checklistKey` on any GBIF endpoint routes the taxon lookups through CoL.
    static let colChecklistKey = "7ddf754f-d193-4cc9-b351-99906754a03b"

    /// Default map tile style. Users can pick a different one in About → Preferences.
    static let defaultMapTileStyle = "classic.point"

    /// Styles available in the GBIF density tile API that we expose in the settings picker.
    static let availableMapTileStyles: [String] = [
        "classic.point",
        "iNaturalist.poly",
        "fire.point",
        "purpleHeat.point",
        "blueHeat.point",
        "glacier.point",
        "orange.marker",
        "blue.marker",
        "scaled.circles",
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
