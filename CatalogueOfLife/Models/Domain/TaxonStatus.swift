import Foundation

enum TaxonStatus: String, Codable, Sendable {
    case accepted
    case provisionallyAccepted = "provisionally accepted"
    case synonym
    case ambiguousSynonym = "ambiguous synonym"
    case misapplied
    case bareName = "bare name"
    case unknown

    init(apiValue: String?) {
        guard let v = apiValue?.lowercased() else { self = .unknown; return }
        self = TaxonStatus(rawValue: v) ?? .unknown
    }

    var isSynonym: Bool {
        switch self {
        case .synonym, .ambiguousSynonym, .misapplied: true
        default: false
        }
    }
}
