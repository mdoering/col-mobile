import Foundation

struct DatasetRef: Equatable, Hashable, Identifiable, Sendable {
    let key: Int
    let alias: String?           // "3LXR", "3LR", or nil
    let title: String
    let version: String?
    let issued: String?
    let citation: String?

    var id: Int { key }

    var supportsGBIF: Bool {
        alias == "3LXR" || alias == "3LR"
    }
}

extension DatasetRef {
    init(dto: DatasetDTO) {
        self.init(
            key: dto.key,
            alias: dto.alias,
            title: dto.title,
            version: dto.version,
            issued: dto.issued,
            citation: dto.citation
        )
    }
}
