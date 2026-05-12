import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("GBIF media decoding")
struct GBIFMediaDecodingTests {
    @Test("Decodes images fixture into GBIFMediaItem list")
    func decodes() throws {
        let data = try FixtureLoader.data("gbif_occurrence_images")
        let dto = try JSONDecoder().decode(OccurrenceWithMediaDTO.self, from: data)
        let items = GBIFMediaItem.from(dto: dto)
        #expect(!items.isEmpty)
        #expect(items.allSatisfy { $0.imageURL.scheme?.hasPrefix("http") == true })
    }

    @Test("Deduplicates by image URL")
    func dedupes() {
        let dto = OccurrenceWithMediaDTO(results: [
            .init(gbifID: "1", media: [
                .init(type: "StillImage", format: nil, identifier: "https://example.org/a.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil)
            ]),
            .init(gbifID: "2", media: [
                .init(type: "StillImage", format: nil, identifier: "https://example.org/a.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil),
                .init(type: "StillImage", format: nil, identifier: "https://example.org/b.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil)
            ])
        ])
        let items = GBIFMediaItem.from(dto: dto)
        #expect(items.count == 2)
        #expect(items.map(\.id).sorted() == ["https://example.org/a.jpg", "https://example.org/b.jpg"])
    }

    @Test("Skips non-StillImage and items without identifier")
    func skipsNonImages() {
        let dto = OccurrenceWithMediaDTO(results: [
            .init(gbifID: "1", media: [
                .init(type: "Sound", format: nil, identifier: "https://example.org/audio.mp3",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil),
                .init(type: "StillImage", format: nil, identifier: nil,
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil),
                .init(type: "StillImage", format: nil, identifier: "https://example.org/ok.jpg",
                      references: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil)
            ])
        ])
        let items = GBIFMediaItem.from(dto: dto)
        #expect(items.count == 1)
        #expect(items.first?.imageURL.absoluteString == "https://example.org/ok.jpg")
    }
}
