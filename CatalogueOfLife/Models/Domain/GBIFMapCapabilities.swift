import Foundation

/// Bounding box + occurrence count returned by GBIF's
/// `/v2/map/occurrence/density/capabilities.json`. Drives the initial
/// region of the inline `GBIFMapView`.
struct GBIFMapCapabilities: Sendable, Equatable {
    let minLat: Double
    let maxLat: Double
    let minLng: Double
    let maxLng: Double
    let total: Int

    var hasData: Bool { total > 0 }
}

/// Wire shape of capabilities.json — only the fields we use.
struct GBIFMapCapabilitiesDTO: Decodable, Sendable {
    let minLat: Double?
    let maxLat: Double?
    let minLng: Double?
    let maxLng: Double?
    let total: Int?
}

extension GBIFMapCapabilities {
    init?(dto: GBIFMapCapabilitiesDTO) {
        guard
            let minLat = dto.minLat,
            let maxLat = dto.maxLat,
            let minLng = dto.minLng,
            let maxLng = dto.maxLng
        else { return nil }
        self.init(
            minLat: minLat,
            maxLat: maxLat,
            minLng: minLng,
            maxLng: maxLng,
            total: dto.total ?? 0
        )
    }
}
