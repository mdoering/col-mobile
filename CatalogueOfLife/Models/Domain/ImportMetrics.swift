import Foundation

struct MetricRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: Int
    let rank: Rank?
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
            return MetricRow(id: id, label: label, value: value, rank: nil)
        }
        let summary: [MetricRow] = [
            row("nameCount", "Names", dto.nameCount),
            row("taxonCount", "Accepted taxa", dto.taxonCount),
            row("synonymCount", "Synonyms", dto.synonymCount),
            row("vernacularCount", "Vernacular names", dto.vernacularCount),
            row("referenceCount", "References", dto.referenceCount),
            row("distributionCount", "Distributions", dto.distributionCount),
            row("mediaCount", "Media", dto.mediaCount),
            row("treatmentCount", "Treatments", dto.treatmentCount),
            row("typeMaterialCount", "Type material", dto.typeMaterialCount),
            row("verbatimCount", "Verbatim records", dto.verbatimCount),
        ].compactMap { $0 }

        let sections: [(String, [MetricRow])] = [
            ("Taxa by rank", Self.rankRows("taxaByRank", dto.taxaByRankCount)),
            ("Names by status", Self.stringRows("namesByStatus", dto.namesByStatusCount)),
            ("Synonyms by rank", Self.rankRows("synonymsByRank", dto.synonymsByRankCount)),
            ("Common names", Self.stringRows("vernByLang", dto.vernacularsByLanguageCount).map { row in
                MetricRow(
                    id: row.id,
                    label: Self.languageDisplayName(forCode: row.label) ?? row.label.uppercased(),
                    value: row.value,
                    rank: nil
                )
            }),
        ].filter { !$0.1.isEmpty }

        self.init(
            attempt: dto.attempt,
            finished: dto.finished,
            state: dto.state,
            summary: summary,
            sections: sections
        )
    }

    private static func rankRows(_ idPrefix: String, _ map: [String: Int]?) -> [MetricRow] {
        (map ?? [:])
            .filter { $0.value > 0 }
            .map { (rank: Rank(apiValue: $0.key), value: $0.value, raw: $0.key) }
            .sorted { $0.rank.sortOrder < $1.rank.sortOrder }
            .map { MetricRow(id: "\(idPrefix)/\($0.raw)", label: $0.raw.capitalized, value: $0.value, rank: $0.rank) }
    }

    private static func stringRows(_ idPrefix: String, _ map: [String: Int]?) -> [MetricRow] {
        (map ?? [:])
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { MetricRow(id: "\(idPrefix)/\($0.key)", label: $0.key, value: $0.value, rank: nil) }
    }

    private static func languageDisplayName(forCode code: String) -> String? {
        // The vocab returns codes that are usually ISO 639-3 (3-letter). Locale APIs prefer ISO 639-1 (2-letter).
        let lower = code.lowercased()
        let alpha2: String? = {
            guard lower.count == 3 else { return lower }
            // Convert 639-3 → 639-1 via Locale.LanguageCode (iOS 16+).
            return Locale.LanguageCode(lower).identifier(.alpha2)
        }()
        let candidate = alpha2 ?? lower
        return Locale.current.localizedString(forLanguageCode: candidate)?.capitalized
    }
}
