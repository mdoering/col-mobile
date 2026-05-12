import Foundation

struct MetricRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: Int
}

struct ImportMetrics: Equatable, Sendable {
    let attempt: Int
    let finished: String?
    let state: String?
    let summary: [MetricRow]
    let sections: [(title: String, rows: [MetricRow])]

    static func == (lhs: ImportMetrics, rhs: ImportMetrics) -> Bool {
        lhs.attempt == rhs.attempt &&
        lhs.finished == rhs.finished &&
        lhs.state == rhs.state &&
        lhs.summary == rhs.summary &&
        lhs.sections.count == rhs.sections.count &&
        zip(lhs.sections, rhs.sections).allSatisfy { $0.title == $1.title && $0.rows == $1.rows }
    }
}

extension ImportMetrics {
    init(dto: ImportMetricsDTO) {
        func row(_ id: String, _ label: String, _ value: Int?) -> MetricRow? {
            guard let value, value > 0 else { return nil }
            return MetricRow(id: id, label: label, value: value)
        }
        let summary: [MetricRow] = [
            row("nameCount", "Names", dto.nameCount),
            row("taxonCount", "Accepted taxa", dto.taxonCount),
            row("synonymCount", "Synonyms", dto.synonymCount),
            row("vernacularCount", "Vernacular names", dto.vernacularCount),
            row("referenceCount", "References", dto.referenceCount),
            row("distributionCount", "Distributions", dto.distributionCount),
            row("mediaCount", "Media", dto.mediaCount),
            row("estimateCount", "Estimates", dto.estimateCount),
            row("treatmentCount", "Treatments", dto.treatmentCount),
            row("typeMaterialCount", "Type material", dto.typeMaterialCount),
            row("verbatimCount", "Verbatim records", dto.verbatimCount),
        ].compactMap { $0 }

        func mapRows(_ id: String, _ map: [String: Int]?) -> [MetricRow] {
            (map ?? [:])
                .filter { $0.value > 0 }
                .sorted { $0.value > $1.value }
                .map { MetricRow(id: "\(id)/\($0.key)", label: $0.key.capitalized, value: $0.value) }
        }

        let sections: [(String, [MetricRow])] = [
            ("Taxa by rank", mapRows("taxaByRank", dto.taxaByRankCount)),
            ("Names by rank", mapRows("namesByRank", dto.namesByRankCount)),
            ("Names by status", mapRows("namesByStatus", dto.namesByStatusCount)),
            ("Synonyms by rank", mapRows("synonymsByRank", dto.synonymsByRankCount)),
            ("Vernaculars by language", mapRows("vernByLang", dto.vernacularsByLanguageCount)),
        ].filter { !$0.1.isEmpty }

        self.init(
            attempt: dto.attempt,
            finished: dto.finished,
            state: dto.state,
            summary: summary,
            sections: sections
        )
    }
}
