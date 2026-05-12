import Foundation

struct TaxonInfoDTO: Decodable, Sendable {
    let usage: UsageDTO
    let group: String?
    let classification: [ClassificationDTO]?
    let synonyms: SynonymsDTO?
    let vernacularNames: [VernacularNameDTO]?

    struct UsageDTO: Decodable, Sendable {
        let id: String
        let name: NameDTO
        let status: String?
    }

    struct NameDTO: Decodable, Sendable {
        let scientificName: String
        let authorship: String?
        let rank: String?
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
}
