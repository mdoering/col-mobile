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

    @Test("merged decodes to true when present, defaults to false otherwise")
    func decodesMergedFlag() throws {
        let mergedJSON = #"{"key": 1, "title": "Merged Source", "merged": true}"#
        let mergedSource = Source(dto: try JSONDecoder().decode(SourceDTO.self, from: Data(mergedJSON.utf8)))
        #expect(mergedSource.merged == true)

        let plainJSON = #"{"key": 2, "title": "Plain Source"}"#
        let plainSource = Source(dto: try JSONDecoder().decode(SourceDTO.self, from: Data(plainJSON.utf8)))
        #expect(plainSource.merged == false)
    }
}
