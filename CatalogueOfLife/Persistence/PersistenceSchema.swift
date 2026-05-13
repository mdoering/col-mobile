import Foundation
import SwiftData

/// Versioned SwiftData schema for the app's persistent store.
///
/// **Why versioned?** Once the app is shipping, the store file on a user's
/// device is the authoritative source of their favorites and recents. If we
/// ever rename, retype, or remove a property on `Favorite` / `RecentTaxon`,
/// SwiftData refuses to open the existing store and the user loses their
/// data. A versioned schema + `SchemaMigrationPlan` lets us define those
/// changes explicitly so the migration runs on first launch of the new
/// version instead of dropping data.
///
/// **Today (v1.0.0):** just the current shape. The plan has no stages yet,
/// so any existing unversioned store from earlier builds opens unchanged —
/// the entity names + property layouts are identical.
///
/// **When you change a model:** add a `SchemaV2`, point the new entity types
/// at it, add a `MigrationStage` to `PersistenceMigrationPlan.stages`. See
/// Apple's "Adopting versioned schemas" docs for stage authoring.
enum PersistenceSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Favorite.self, RecentTaxon.self] }
}

enum PersistenceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PersistenceSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
