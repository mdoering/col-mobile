import Foundation

struct DatasetRef: Equatable, Hashable, Identifiable, Sendable {
    let key: Int
    let alias: String?       // human label, e.g. "COL26.4 XR" — NOT the URL alias "3LXR"
    let title: String
    let version: String?
    let issued: String?
    let origin: String?      // "release" | "xrelease" | "project" | "external"
    let citation: String?
    let doi: String?
    let license: String?
    let publisher: String?   // synthesized display string like "Catalogue of Life Foundation, Amsterdam, NL"

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
            citation: dto.citation,
            doi: dto.doi,
            license: dto.license,
            publisher: Self.formatPublisher(dto.publisher)
        )
    }

    private static func formatPublisher(_ p: DatasetDTO.PublisherDTO?) -> String? {
        guard let p else { return nil }
        let parts = [p.organisation ?? p.name, p.city, p.country].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

extension DatasetRef {
    /// Sort: latest extended (matches `latestExtendedKey`) first, latest base (matches `latestBaseKey`) second,
    /// remaining releases by `issued` descending. Pass `nil` for unknown resolved keys.
    static func sortedForPicker(_ refs: [DatasetRef],
                                 latestExtendedKey: Int?,
                                 latestBaseKey: Int?) -> [DatasetRef] {
        refs.sorted { a, b in
            func rank(_ r: DatasetRef) -> Int {
                if let k = latestExtendedKey, r.key == k { return 0 }
                if let k = latestBaseKey, r.key == k { return 1 }
                return 2
            }
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return (a.issued ?? "") > (b.issued ?? "")
        }
    }
}
