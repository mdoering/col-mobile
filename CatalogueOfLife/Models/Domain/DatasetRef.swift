import Foundation

struct DatasetRef: Equatable, Hashable, Identifiable, Sendable {
    let key: Int
    let alias: String?       // human label, e.g. "COL26.4 XR" — NOT the URL alias "3LXR"
    let title: String
    let version: String?
    let issued: String?
    let origin: String?      // "release" | "xrelease" | "project" | "external"
    let citation: String?

    var id: Int { key }
}

extension DatasetRef {
    init(dto: DatasetDTO) {
        self.init(
            key: dto.key,
            alias: dto.alias,
            title: dto.title,
            version: dto.version,
            issued: dto.issued,
            origin: dto.origin,
            citation: dto.citation
        )
    }
}
