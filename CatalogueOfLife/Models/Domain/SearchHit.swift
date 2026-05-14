import Foundation

struct SearchHit: Equatable, Identifiable, Sendable {
    struct Vernacular: Equatable, Sendable {
        let name: String
        let language: String?    // ISO 639-3 code
    }

    let id: String
    let scientificName: String
    let authorship: String?
    let rank: Rank
    let status: TaxonStatus
    let acceptedId: String?
    let acceptedName: String?
    let group: String?
    let merged: Bool
    let extinct: Bool
    /// Populated when the search was issued with `content=VERNACULAR_NAME`. Empty otherwise.
    let vernacularNames: [Vernacular]

    /// Taxon id to navigate to on row tap. Returns nil for a synonym hit whose
    /// accepted target wasn't included in the response — callers should disable the row.
    var navigationTaxonId: String? {
        if let accepted = acceptedId { return accepted }
        return status.isSynonym ? nil : id
    }

    /// Picks the vernacular name to display on the primary row of a vernacular
    /// search hit, falling through user-language → English → first available.
    /// Returns the chosen name and a language-code suffix (only when neither the
    /// preferred language nor English produced a match — so the user can see
    /// what language the surfaced name is in).
    func preferredVernacular(language: String?) -> (name: String, languageSuffix: String?)? {
        guard !vernacularNames.isEmpty else { return nil }
        if let lang = language,
           let v = vernacularNames.first(where: { $0.language?.lowercased() == lang.lowercased() }) {
            return (v.name, nil)
        }
        if let v = vernacularNames.first(where: { $0.language?.lowercased() == "eng" }) {
            return (v.name, nil)
        }
        let v = vernacularNames[0]
        return (v.name, v.language)
    }
}
