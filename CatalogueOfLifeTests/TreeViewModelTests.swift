import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("TreeViewModel")
@MainActor
struct TreeViewModelTests {
    @Test("Loads root nodes from client")
    func loadsRoot() async {
        let stub = StubAPIClient()
        stub.treeChildren["root"] = [
            TreeNode(id: "K1", name: "Animalia", authorship: nil, rank: .kingdom, status: .accepted, count: 100, childCount: 5)
        ]
        let vm = TreeViewModel(parentId: nil, parentName: nil, client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(nodes) = vm.state {
            #expect(nodes.first?.name == "Animalia")
        } else {
            Issue.record("Expected .loaded; got \(vm.state)")
        }
    }

    @Test("Loads children of a specific parent")
    func loadsChildren() async {
        let stub = StubAPIClient()
        stub.treeChildren["K1"] = [
            TreeNode(id: "P1", name: "Chordata", authorship: nil, rank: .phylum, status: .accepted, count: 10, childCount: 3)
        ]
        let vm = TreeViewModel(parentId: "K1", parentName: "Animalia", client: stub, getDatasetKey: { 9837 })
        await vm.load()
        if case let .loaded(nodes) = vm.state {
            #expect(nodes.first?.rank == .phylum)
        } else {
            Issue.record("Expected .loaded")
        }
    }

    @Test("Server error surfaces as .failed")
    func errorSurfaces() async {
        let stub = StubAPIClient()
        stub.error = .server(status: 500)
        let vm = TreeViewModel(parentId: nil, parentName: nil, client: stub, getDatasetKey: { 9837 })
        await vm.load()
        #expect(vm.state == .failed(.server(status: 500)))
    }
}
