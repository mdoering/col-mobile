import Foundation

struct Source: Equatable, Hashable, Identifiable, Sendable {
    let key: Int
    let title: String
    let alias: String?
    let citation: String?
    let logoURL: URL?
    let license: String?
    let version: String?
    let issued: String?
    let taxonomicScope: String?
    let geographicScope: String?
    let description: String?
    let websiteURL: URL?
    let doi: String?

    var id: Int { key }
}

extension Source {
    init(dto: SourceDTO) {
        self.init(
            key: dto.key,
            title: dto.title,
            alias: dto.alias,
            citation: dto.citation,
            logoURL: dto.logo.flatMap(URL.init(string:)),
            license: dto.license,
            version: dto.version,
            issued: dto.issued,
            taxonomicScope: dto.taxonomicScope,
            geographicScope: dto.geographicScope,
            description: dto.description,
            websiteURL: dto.url.flatMap(URL.init(string:)),
            doi: dto.doi
        )
    }
}
