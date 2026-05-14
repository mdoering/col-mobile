import Foundation

struct NameRelation: Equatable, Identifiable, Sendable {
    /// Synthesized: "<usageId>↔<relatedUsageId>:<type>"
    let id: String
    let type: String
    let relatedUsageId: String?
    let relatedNameId: String?
}

struct TypeMaterialEntry: Equatable, Identifiable, Sendable {
    let id: String
    let citation: String?
    let status: String?
    let institutionCode: String?
    let catalogNumber: String?
    let link: URL?
}

struct TaxonInfo: Equatable, Sendable {
    let taxonId: String
    let scientificName: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let group: String?
    let classification: [ClassificationItem]
    let synonymyGroups: [SynonymyGroup]
    let vernacularNames: [VernacularName]
    let publishedInCitation: String?
    let sourceDatasetKey: Int?
    let nameRelations: [NameRelation]
    let merged: Bool
    let extinct: Bool
    let remarks: String?
    let etymology: String?
    let typeMaterials: [TypeMaterialEntry]
}

extension TaxonInfo {
    func preferredVernacular(language: String?) -> VernacularName? {
        guard let language else { return nil }
        return vernacularNames.first { $0.language == language }
    }
}

extension TaxonInfo {
    init(dto: TaxonInfoDTO) {
        let u = dto.usage
        let classification = (dto.classification ?? []).map {
            ClassificationItem(id: $0.id, name: $0.name, rank: Rank(apiValue: $0.rank))
        }
        let synonymyGroups = dto.synonyms.map { SynonymyGroup.group(synonymsDTO: $0, parentId: u.id) } ?? []
        let rawVernaculars = (dto.vernacularNames ?? []).map { v in
            VernacularName(
                id: String(v.id),
                name: v.name,
                language: v.language,
                country: v.country,
                area: v.area
            )
        }
        // Dedupe by (name, language) — sources sometimes contribute the same
        // common name in the same language multiple times. Case-insensitive on
        // both so "Grey squirrel" + "grey squirrel" collapse.
        var seenVernKeys = Set<String>()
        let vernaculars = rawVernaculars.filter { v in
            let key = "\(v.name.lowercased())|\(v.language?.lowercased() ?? "")"
            return seenVernKeys.insert(key).inserted
        }
        let nameRelations = (dto.nameRelations ?? []).enumerated().map { idx, r in
            NameRelation(
                id: "\(r.usageId ?? "")-\(r.relatedUsageId ?? "")-\(idx)",
                type: r.type,
                relatedUsageId: r.relatedUsageId,
                relatedNameId: r.relatedNameId
            )
        }
        let tm: [TypeMaterialEntry] = (dto.typeMaterial ?? [:])
            .values
            .flatMap { $0 }
            .enumerated()
            .map { idx, t in
                TypeMaterialEntry(
                    id: t.id ?? "tm-\(idx)",
                    citation: t.citation,
                    status: t.status,
                    institutionCode: t.institutionCode,
                    catalogNumber: t.catalogNumber,
                    link: t.link.flatMap(URL.init(string:))
                )
            }
        self.init(
            taxonId: u.id,
            scientificName: u.name.scientificName,
            authorship: u.name.authorship,
            rank: Rank(apiValue: u.name.rank),
            status: TaxonStatus(apiValue: u.status),
            group: dto.group,
            classification: classification,
            synonymyGroups: synonymyGroups,
            vernacularNames: vernaculars,
            publishedInCitation: dto.publishedIn?.citation,
            sourceDatasetKey: dto.source?.sourceDatasetKey,
            nameRelations: nameRelations,
            merged: u.merged ?? false,
            extinct: u.extinct ?? false,
            remarks: u.remarks,
            etymology: u.name.etymology,
            typeMaterials: tm
        )
    }
}
