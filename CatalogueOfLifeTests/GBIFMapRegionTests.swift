import Testing
import Foundation
import MapKit
@testable import CatalogueOfLife

@Suite("GBIF map region")
struct GBIFMapRegionTests {
    @Test("Bbox fully inside [-180,180] yields a finite region around the centre")
    func normalBbox() {
        let caps = GBIFMapCapabilities(minLat: 30, maxLat: 60, minLng: -10, maxLng: 30, total: 100)
        let region = MKCoordinateRegion(capabilities: caps)
        #expect(region != nil)
        #expect(region?.isValidForMap == true)
        #expect(abs((region?.center.latitude ?? 0) - 45) < 0.001)
        #expect(abs((region?.center.longitude ?? 0) - 10) < 0.001)
    }

    @Test("Bbox extending past +180 longitude falls back to worldExcludingPoles")
    func wraparoundFallsBackToWorld() {
        // Real-world example: GBIF taxon CQKF reported a Pacific bbox that
        // extended beyond +180. Without the guard, MapKit crashes with
        // NSInvalidArgumentException when the resulting region is applied.
        let caps = GBIFMapCapabilities(minLat: -5, maxLat: 60, minLng: 94, maxLng: 291, total: 100)
        let region = MKCoordinateRegion(capabilities: caps)
        #expect(region?.isValidForMap == true)
        #expect(region?.center.longitude == MKCoordinateRegion.worldExcludingPoles.center.longitude)
    }

    @Test("Bbox extending past -180 longitude also falls back")
    func negativeWraparoundFallsBack() {
        let caps = GBIFMapCapabilities(minLat: -60, maxLat: 60, minLng: -200, maxLng: 50, total: 100)
        let region = MKCoordinateRegion(capabilities: caps)
        #expect(region?.isValidForMap == true)
    }

    @Test("isValidForMap rejects out-of-range centres and infinities")
    func validityCheck() {
        let bad = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 27, longitude: 192.5),
            span: MKCoordinateSpan(latitudeDelta: 64.4, longitudeDelta: 275.8)
        )
        #expect(bad.isValidForMap == false)

        let good = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        #expect(good.isValidForMap == true)
    }
}
