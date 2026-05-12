import Foundation

/// Summary of GBIF occurrence stats for one taxon.
struct GBIFMetrics: Equatable, Sendable {
    let occurrenceCount: Int
    let distinctCountries: Int
    let distinctDatasets: Int
    /// Up to 3 top countries by occurrence count, (ISO 3166 alpha-2, count).
    let topCountries: [(code: String, count: Int)]

    static func == (lhs: GBIFMetrics, rhs: GBIFMetrics) -> Bool {
        lhs.occurrenceCount == rhs.occurrenceCount &&
        lhs.distinctCountries == rhs.distinctCountries &&
        lhs.distinctDatasets == rhs.distinctDatasets &&
        lhs.topCountries.count == rhs.topCountries.count &&
        zip(lhs.topCountries, rhs.topCountries).allSatisfy { $0.code == $1.code && $0.count == $1.count }
    }
}

extension GBIFMetrics {
    init(dto: OccurrenceSearchDTO) {
        let facets = dto.facets ?? []
        let countryFacet = facets.first { $0.field.uppercased() == "COUNTRY" }
        let datasetFacet = facets.first { $0.field.uppercased() == "DATASET_KEY" }
        self.init(
            occurrenceCount: dto.count,
            distinctCountries: countryFacet?.counts.count ?? 0,
            distinctDatasets: datasetFacet?.counts.count ?? 0,
            topCountries: (countryFacet?.counts.prefix(3).map { (code: $0.name, count: $0.count) }) ?? []
        )
    }
}
