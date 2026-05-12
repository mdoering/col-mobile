import Foundation

struct SynonymyEntry: Equatable, Identifiable, Sendable {
    let id: String
    let scientificName: String
    let authorship: String?
    let rank: Rank
}

struct SynonymyGroup: Equatable, Identifiable, Sendable {
    enum Kind: String, Sendable { case homotypic, heterotypic }
    let id: String
    let kind: Kind
    let entries: [SynonymyEntry]
}

extension SynonymyGroup {
    /// Build synonym groups from the structured DTO.
    ///
    /// The real API returns:
    ///   - `homotypic`          — flat list of homotypic synonyms (one group)
    ///   - `heterotypicGroups`  — list of lists, each sub-list is a basionym bucket
    ///
    /// We emit one `.homotypic` group (if non-empty) followed by one `.heterotypic`
    /// group per basionym bucket (if non-empty).
    static func group(synonymsDTO: TaxonInfoDTO.SynonymsDTO) -> [SynonymyGroup] {
        var groups: [SynonymyGroup] = []

        // Homotypic: all share a single group
        let homoEntries = (synonymsDTO.homotypic ?? []).map { entry(from: $0) }
        if !homoEntries.isEmpty {
            groups.append(SynonymyGroup(id: "homotypic", kind: .homotypic, entries: homoEntries))
        }

        // Heterotypic: one group per basionym bucket
        let heteroGroups = synonymsDTO.heterotypicGroups ?? []
        for (idx, bucket) in heteroGroups.enumerated() {
            let entries = bucket.map { entry(from: $0) }
            if !entries.isEmpty {
                let groupId = entries.first.map { "heterotypic-\($0.id)" } ?? "heterotypic-\(idx)"
                groups.append(SynonymyGroup(id: groupId, kind: .heterotypic, entries: entries))
            }
        }

        // Fallback: if heterotypicGroups is absent but heterotypic flat list is present,
        // use the flat list as a single heterotypic group.
        if heteroGroups.isEmpty, let flatHetero = synonymsDTO.heterotypic, !flatHetero.isEmpty {
            let entries = flatHetero.map { entry(from: $0) }
            groups.append(SynonymyGroup(id: "heterotypic", kind: .heterotypic, entries: entries))
        }

        return groups
    }

    private static func entry(from dto: TaxonInfoDTO.SynonymEntryDTO) -> SynonymyEntry {
        SynonymyEntry(
            id: dto.id,
            scientificName: dto.name.scientificName,
            authorship: dto.name.authorship,
            rank: Rank(apiValue: dto.name.rank)
        )
    }
}
