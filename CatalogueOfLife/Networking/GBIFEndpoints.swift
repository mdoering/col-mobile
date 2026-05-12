import Foundation

enum GBIFEndpoints {
    static let baseURL = URL(string: "https://api.gbif.org")!

    /// GBIF's unique checklist UUID for the latest Catalogue of Life release.
    /// `checklistKey` on any GBIF endpoint routes the taxon lookups through CoL.
    static let colChecklistKey = "7ddf754f-d193-4cc9-b351-99906754a03b"

    /// Map tile style used by the density overlay.
    static let mapTileStyle = "classic.point"

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

    /// `GET /v2/map/occurrence/density/{z}/{x}/{y}@1x.png?...` — tile template for `MKTileOverlay`.
    static func mapTileURLTemplate(taxonId: String) -> String {
        "\(baseURL.absoluteString)/v2/map/occurrence/density/{z}/{x}/{y}@1x.png?checklistKey=\(colChecklistKey)&taxonId=\(taxonId)&style=\(mapTileStyle)"
    }
}
