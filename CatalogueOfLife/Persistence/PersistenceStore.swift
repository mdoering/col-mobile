import Foundation
import SwiftData

enum PersistenceStore {
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema(versionedSchema: PersistenceSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: PersistenceMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create persistent ModelContainer: \(error)")
        }
    }()

    @MainActor
    static func makeInMemory() -> ModelContainer {
        let schema = Schema(versionedSchema: PersistenceSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    static let recentsCap = 50

    @MainActor
    static func bumpRecent(_ context: ModelContext,
                            datasetKey: Int,
                            taxonId: String,
                            name: String,
                            rank: String,
                            group: String?) {
        let key = Favorite.key(datasetKey: datasetKey, taxonId: taxonId)
        let descriptor = FetchDescriptor<RecentTaxon>(predicate: #Predicate { $0.compositeKey == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.lastVisited = Date()
            existing.name = name
            existing.rank = rank
            existing.group = group
        } else {
            let row = RecentTaxon(datasetKey: datasetKey, taxonId: taxonId, name: name, rank: rank, group: group)
            context.insert(row)
        }
        try? context.save()
        evictOldRecents(context)
    }

    @MainActor
    private static func evictOldRecents(_ context: ModelContext) {
        var fd = FetchDescriptor<RecentTaxon>(sortBy: [SortDescriptor(\.lastVisited, order: .reverse)])
        fd.fetchLimit = 0
        guard let all = try? context.fetch(fd) else { return }
        guard all.count > recentsCap else { return }
        for row in all[recentsCap...] {
            context.delete(row)
        }
        try? context.save()
    }
}
