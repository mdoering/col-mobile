import Foundation

struct TaxonInfoDTO: Decodable, Sendable {
    let usage: UsageDTO
    let group: String?
    let classification: [ClassificationDTO]?
    let synonyms: SynonymsDTO?
    let vernacularNames: [VernacularNameDTO]?
    let publishedIn: PublishedInDTO?
    let source: SourceRefDTO?
    let nameRelations: [NameRelationDTO]?
    let typeMaterial: [String: [TypeMaterialDTO]]?

    struct UsageDTO: Decodable, Sendable {
        let id: String
        let name: NameDTO
        let status: String?
        let group: String?
        let merged: Bool?
        let extinct: Bool?
        let remarks: String?
    }

    struct NameDTO: Decodable, Sendable {
        let scientificName: String
        let authorship: String?
        let rank: String?
        let etymology: String?
    }

    struct ClassificationDTO: Decodable, Sendable {
        let id: String
        let name: String
        let rank: String?
    }

    /// The real API returns synonyms as a structured dict:
    ///   homotypic: [SynonymEntryDTO]            — flat list of homotypic synonyms
    ///   heterotypic: [SynonymEntryDTO]          — flat list (all heterotypic, de-duped from groups)
    ///   heterotypicGroups: [[SynonymEntryDTO]]  — heterotypic synonyms grouped by basionym
    struct SynonymsDTO: Decodable, Sendable {
        let homotypic: [SynonymEntryDTO]?
        let heterotypic: [SynonymEntryDTO]?
        let heterotypicGroups: [[SynonymEntryDTO]]?
    }

    struct SynonymEntryDTO: Decodable, Sendable {
        let id: String
        let name: NameDTO
        let status: String?
    }

    struct PublishedInDTO: Decodable, Sendable {
        let citation: String?
        let id: String?
    }

    struct SourceRefDTO: Decodable, Sendable {
        let sourceDatasetKey: Int?
        let sectorKey: Int?
        let sourceEntity: String?
        let sourceId: String?
    }

    struct NameRelationDTO: Decodable, Sendable {
        let type: String
        let usageId: String?
        let relatedUsageId: String?
    }

    struct TypeMaterialDTO: Decodable, Sendable {
        let id: String?
        let citation: String?
        let status: String?
        let institutionCode: String?
        let catalogNumber: String?
        let link: String?
        let merged: Bool?
    }
}
