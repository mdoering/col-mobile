import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Dataset decoding")
struct DatasetDecodingTests {
    @Test("Decodes /dataset/3LXR fixture into DatasetRef")
    func decodes3LXR() throws {
        let data = try FixtureLoader.data("dataset_3LXR")
        let dto = try JSONDecoder().decode(DatasetDTO.self, from: data)
        let ref = DatasetRef(dto: dto)
        // Actual alias returned by the API for the 3LXR route is "COL26.4 XR"
        #expect(ref.alias == "COL26.4 XR")
        #expect(ref.title.localizedCaseInsensitiveContains("Catalogue of Life"))
        // "3LXR" alias is a route alias, not what the API stores in the alias field
        #expect(ref.supportsGBIF == false)
    }
}
