import Foundation

enum Rank: String, Codable, Sendable, CaseIterable {
    case domain, superkingdom, kingdom, subkingdom, infrakingdom
    case phylum, subphylum, superclass
    case `class` = "class", subclass, infraclass
    case superorder, order, suborder, infraorder
    case superfamily, family, subfamily, tribe, subtribe
    case genus, subgenus, section, subsection, series
    case species, subspecies, variety, form
    case unranked, other

    init(apiValue: String?) {
        guard let v = apiValue?.lowercased() else { self = .other; return }
        self = Rank(rawValue: v) ?? .other
    }
}
