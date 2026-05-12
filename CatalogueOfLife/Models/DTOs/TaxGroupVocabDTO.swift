import Foundation

/// Wire shape from `GET /vocab/taxgroup`. Lives at the response root as a JSON array.
struct TaxGroupVocabDTO: Decodable, Sendable {
    let codes: [String]
    let name: String
    let description: String?
    let icon: String?
    let iconSVG: String?
    let phylopic: String?
    let parents: [String]?
    let primaryParent: String?
    let other: Bool?
}
