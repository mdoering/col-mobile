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

    @Test("Decodes /dataset list and surfaces both origins")
    func decodesReleaseList() throws {
        let data = try FixtureLoader.data("dataset_list")
        let paged = try JSONDecoder().decode(PagedDTO<DatasetDTO>.self, from: data)
        let refs = paged.result.map(DatasetRef.init(dto:))
        #expect(!refs.isEmpty)
        let origins = Set(refs.compactMap(\.origin))
        #expect(origins.contains("release"))
        #expect(origins.contains("xrelease"))
    }

    @Test("sortedForPicker puts latest extended first, latest base second, others by issued desc")
    func sortPlacesLatestReleasesFirst() {
        let refs = [
            DatasetRef(key: 11, alias: "COL24",      title: "C", version: nil, issued: "2024-01-01", origin: "release",  citation: nil, doi: nil, license: nil, publisher: nil),
            DatasetRef(key: 12, alias: "COL26.4 XR", title: "C", version: nil, issued: "2026-04-01", origin: "xrelease", citation: nil, doi: nil, license: nil, publisher: nil),
            DatasetRef(key: 13, alias: "COL26.4",    title: "C", version: nil, issued: "2026-04-15", origin: "release",  citation: nil, doi: nil, license: nil, publisher: nil),
            DatasetRef(key: 14, alias: "COL25",      title: "C", version: nil, issued: "2025-01-01", origin: "release",  citation: nil, doi: nil, license: nil, publisher: nil),
        ]
        let sorted = DatasetRef.sortedForPicker(refs, latestExtendedKey: 12, latestBaseKey: 13)
        #expect(sorted.map(\.key) == [12, 13, 14, 11])
    }
}
