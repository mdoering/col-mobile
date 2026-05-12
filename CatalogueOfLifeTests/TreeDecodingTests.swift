import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Tree decoding")
struct TreeDecodingTests {
    @Test("Root tree response decodes into TreeNodes")
    func decodesRoot() throws {
        let data = try FixtureLoader.data("tree_root")
        let paged = try JSONDecoder().decode(PagedDTO<TreeNodeDTO>.self, from: data)
        let nodes = paged.result.map(TreeNode.init(dto:))
        #expect(!nodes.isEmpty)
        #expect(nodes.allSatisfy { $0.id.count > 0 })
    }

    @Test("Children response decodes the same shape")
    func decodesChildren() throws {
        let data = try FixtureLoader.data("tree_children")
        let paged = try JSONDecoder().decode(PagedDTO<TreeNodeDTO>.self, from: data)
        let nodes = paged.result.map(TreeNode.init(dto:))
        #expect(!nodes.isEmpty)
    }
}
