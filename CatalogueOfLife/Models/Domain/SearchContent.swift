import Foundation

/// Which name field the `/nameusage/search` endpoint should match against.
/// Maps to the API's `content` query parameter.
enum SearchContent: String, CaseIterable, Sendable {
    case scientific
    case vernacular

    var apiValue: String {
        switch self {
        case .scientific: "SCIENTIFIC_NAME"
        case .vernacular: "VERNACULAR_NAME"
        }
    }
}
