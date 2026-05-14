import Foundation

/// Wire shape for both `GET /dataset/{key}/source[?...]` and `GET /dataset/{key}/source/{sourceKey}`.
/// The list endpoint returns a subset; the detail endpoint returns a superset. We decode both
/// through the same struct with optionals for the detail-only fields.
struct SourceDTO: Decodable, Sendable {
    let key: Int
    let title: String
    let alias: String?
    let citation: String?
    let logo: String?
    let license: String?
    let version: String?
    let issued: String?
    let type: String?
    let origin: String?
    /// True for sources merged into an extended release (XR). Absent on plain
    /// release datasets, where it's effectively `false` for everything.
    let merged: Bool?
    let taxonomicScope: String?
    let geographicScope: String?
    let creator: [PersonDTO]?
    let contact: PersonDTO?
    // Detail-only:
    let description: String?
    let contributor: [PersonDTO]?
    let imported: String?
    let versionDoi: String?
    let url: String?
    let doi: String?

    struct PersonDTO: Decodable, Sendable {
        let given: String?
        let family: String?
        let organisation: String?
        let email: String?
    }
}
