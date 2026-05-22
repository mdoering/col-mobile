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

    @Test("loadMore appends the next page and stops when the total is reached")
    func paginatesLargeChildList() async {
        let stub = StubAPIClient()
        // 250 children — three pages at 100 per page (100 + 100 + 50).
        let kids: [TreeNode] = (0..<250).map { i in
            TreeNode(id: "S\(i)", name: "Species \(i)", authorship: nil,
                     rank: .species, status: .accepted, count: 0, childCount: 0)
        }
        stub.treeChildren["G1"] = kids
        let vm = TreeViewModel(parentId: "G1", parentName: "Astragalus", client: stub, getDatasetKey: { 9837 })

        await vm.load()
        guard case let .loaded(first) = vm.state else { Issue.record("Expected .loaded after load()"); return }
        #expect(first.count == 100)
        #expect(vm.hasMore == true)

        await vm.loadMore()
        guard case let .loaded(second) = vm.state else { Issue.record("Expected .loaded after loadMore #1"); return }
        #expect(second.count == 200)
        #expect(vm.hasMore == true)

        await vm.loadMore()
        guard case let .loaded(third) = vm.state else { Issue.record("Expected .loaded after loadMore #2"); return }
        #expect(third.count == 250)
        #expect(vm.hasMore == false)

        // Calling loadMore again at the end is a no-op.
        await vm.loadMore()
        if case let .loaded(stillFull) = vm.state {
            #expect(stillFull.count == 250)
        } else {
            Issue.record("Expected .loaded to stay populated after over-fetching")
        }
    }

    @Test("The 'Not assigned' placeholder stays at the end across loadMore calls")
    func placeholderStaysAtTheEnd() async {
        let stub = StubAPIClient()
        // 150 real children — exercises one loadMore.
        let kids: [TreeNode] = (0..<150).map { i in
            TreeNode(id: "S\(i)", name: "Species \(i)", authorship: nil,
                     rank: .species, status: .accepted, count: 0, childCount: 0)
        }
        stub.treeChildren["G1"] = kids
        // Server appends this placeholder to every non-empty page.
        stub.treeChildrenPlaceholder["G1"] = TreeNode(
            id: "G1--incertae-sedis--SPECIES", name: "Not assigned",
            authorship: nil, rank: .species, status: .accepted,
            count: 27, childCount: 27
        )
        let vm = TreeViewModel(parentId: "G1", parentName: "Astragalus", client: stub, getDatasetKey: { 9837 })

        await vm.load()
        guard case let .loaded(first) = vm.state else { Issue.record("Expected .loaded after load()"); return }
        // 100 species + placeholder.
        #expect(first.count == 101)
        #expect(first.last?.isPlaceholder == true)
        #expect(vm.hasMore == true)

        await vm.loadMore()
        guard case let .loaded(second) = vm.state else { Issue.record("Expected .loaded after loadMore"); return }
        // 150 species + exactly one placeholder, placeholder still last.
        #expect(second.count == 151)
        #expect(second.last?.isPlaceholder == true)
        #expect(second.filter(\.isPlaceholder).count == 1)
        // Real children remain in order and are not interleaved with the placeholder.
        let realIds = second.filter { !$0.isPlaceholder }.map(\.id)
        #expect(realIds == kids.map(\.id))
        #expect(vm.hasMore == false)
    }
}
