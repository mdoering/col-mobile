import Foundation

struct TaxonSuggestion: Equatable, Identifiable, Sendable {
    let id: String                 // == usageId
    let scientificName: String     // == match
    let context: String?
    let rank: Rank
    let group: String?
    let suggestion: String         // display string
}

extension TaxonSuggestion {
    init(dto: SuggestEntryDTO) {
        self.init(
            id: dto.usageId,
            scientificName: dto.match ?? "",
            context: dto.context,
            rank: Rank(apiValue: dto.rank),
            group: dto.group,
            suggestion: dto.suggestion
        )
    }
}
