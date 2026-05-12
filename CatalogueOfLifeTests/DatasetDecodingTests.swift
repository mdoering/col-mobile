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
        #expect(ref.title.localizedCaseInsensitiveContains("Catalogue of Life"))
        #expect(ref.origin == "xrelease")          // /dataset/3LXR resolves to an xrelease
        #expect(ref.key > 0)
        // We intentionally do NOT assert on ref.alias — the human label drifts (COL26.4 XR, COL27.0 XR, ...).
    }
}
