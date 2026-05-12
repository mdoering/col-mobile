import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Source decoding")
struct SourceDecodingTests {
    @Test("Decodes the sources list fixture")
    func decodesList() throws {
        let data = try FixtureLoader.data("sources_list")
        let dtos = try JSONDecoder().decode([SourceDTO].self, from: data)
        let sources = dtos.map(Source.init(dto:))
        #expect(!sources.isEmpty)
        #expect(sources.allSatisfy { !$0.title.isEmpty })
    }

    @Test("Decodes the source detail fixture")
    func decodesDetail() throws {
        let data = try FixtureLoader.data("source_detail")
        let dto = try JSONDecoder().decode(SourceDTO.self, from: data)
        let source = Source(dto: dto)
        #expect(!source.title.isEmpty)
        #expect(source.key > 0)
    }
}
