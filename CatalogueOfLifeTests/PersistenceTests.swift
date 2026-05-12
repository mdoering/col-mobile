import Testing
import Foundation
import SwiftData
@testable import CatalogueOfLife

@Suite("Persistence")
@MainActor
struct PersistenceTests {

    private func freshContext() -> ModelContext {
        let container = PersistenceStore.makeInMemory()
        return ModelContext(container)
    }

    @Test("Bumping a new taxon inserts a RecentTaxon row")
    func bumpsNewTaxon() throws {
        let ctx = freshContext()
        PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T1", name: "Felis catus", rank: "species", group: "mammals")
        let rows = try ctx.fetch(FetchDescriptor<RecentTaxon>())
        #expect(rows.count == 1)
        #expect(rows.first?.taxonId == "T1")
        #expect(rows.first?.compositeKey == "1:T1")
    }

    @Test("Bumping an existing taxon updates lastVisited (does not duplicate)")
    func bumpsExistingTaxon() async throws {
        let ctx = freshContext()
        PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T1", name: "Felis catus", rank: "species", group: nil)
        let firstVisit = try ctx.fetch(FetchDescriptor<RecentTaxon>()).first?.lastVisited
        try await Task.sleep(nanoseconds: 5_000_000)
        PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T1", name: "Felis catus", rank: "species", group: "mammals")
        let rows = try ctx.fetch(FetchDescriptor<RecentTaxon>())
        #expect(rows.count == 1)
        #expect((rows.first?.lastVisited ?? Date.distantPast) > (firstVisit ?? Date.distantFuture))
        #expect(rows.first?.group == "mammals")
    }

    @Test("Recents cap at 50: oldest are evicted")
    func capsAtFifty() throws {
        let ctx = freshContext()
        for i in 1...55 {
            PersistenceStore.bumpRecent(ctx, datasetKey: 1, taxonId: "T\(i)", name: "Name\(i)", rank: "species", group: nil)
        }
        let all = try ctx.fetch(FetchDescriptor<RecentTaxon>(sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]))
        #expect(all.count == 50)
        let ids = Set(all.map(\.taxonId))
        #expect(!ids.contains("T1"))
        #expect(!ids.contains("T5"))
        #expect(ids.contains("T6"))
    }

    @Test("Favorite uniqueness via composite key")
    func favoriteUniqueness() throws {
        let ctx = freshContext()
        ctx.insert(Favorite(datasetKey: 1, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        ctx.insert(Favorite(datasetKey: 1, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        do { try ctx.save() } catch {
            return
        }
        let rows = try ctx.fetch(FetchDescriptor<Favorite>())
        #expect(rows.count == 1, "Expected uniqueness on compositeKey")
    }

    @Test("Same taxon id in different datasets are distinct favorites")
    func datasetScopedFavorites() throws {
        let ctx = freshContext()
        ctx.insert(Favorite(datasetKey: 1, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        ctx.insert(Favorite(datasetKey: 2, taxonId: "T1", name: "Felis", authorship: nil, rank: "species", group: nil))
        try ctx.save()
        let rows = try ctx.fetch(FetchDescriptor<Favorite>())
        #expect(rows.count == 2)
    }
}
