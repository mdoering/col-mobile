import Foundation

/// Decodes one hit from /dataset/{key}/nameusage/search.
///
/// Real API shape (verified against 3LXR, 2026-05-12):
///   - `group` is a top-level field on the search hit (not inside `usage`)
///   - synonyms carry `usage.accepted.id` rather than a top-level `acceptedId`
struct NameUsageSearchHitDTO: Decodable, Sendable {
    let usage: UsageDTO
    /// Group is returned at the top level of the search hit object.
    let group: String?

    struct UsageDTO: Decodable, Sendable {
        let id: String
        let status: String?
        let name: NameDTO
        let merged: Bool?
        let extinct: Bool?
        /// Present when the usage is a synonym; contains the accepted taxon.
        let accepted: AcceptedDTO?
    }

    struct AcceptedDTO: Decodable, Sendable {
        let id: String
        let name: AcceptedNameDTO?
    }

    struct AcceptedNameDTO: Decodable, Sendable {
        let scientificName: String?
        let authorship: String?
    }

    struct NameDTO: Decodable, Sendable {
        let scientificName: String
        let authorship: String?
        let rank: String?
    }
}

extension SearchHit {
    init(dto: NameUsageSearchHitDTO) {
        self.init(
            id: dto.usage.id,
            scientificName: dto.usage.name.scientificName,
            authorship: dto.usage.name.authorship,
            rank: Rank(apiValue: dto.usage.name.rank),
            status: TaxonStatus(apiValue: dto.usage.status),
            acceptedId: dto.usage.accepted?.id,
            acceptedName: dto.usage.accepted?.name?.scientificName,
            group: dto.group,
            merged: dto.usage.merged ?? false,
            extinct: dto.usage.extinct ?? false
        )
    }
}
