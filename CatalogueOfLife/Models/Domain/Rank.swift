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

    /// Ranks above the genus level. The taxonomic-group sunburst only makes sense for
    /// suprageneric taxa; for a genus and below, show a descendants-by-rank summary instead.
    var isSuprageneric: Bool {
        switch self {
        case .domain, .superkingdom, .kingdom, .subkingdom, .infrakingdom,
             .phylum, .subphylum, .superclass,
             .class, .subclass, .infraclass,
             .superorder, .order, .suborder, .infraorder,
             .superfamily, .family, .subfamily, .tribe, .subtribe:
            return true
        case .genus, .subgenus, .section, .subsection, .series,
             .species, .subspecies, .variety, .form,
             .unranked, .other:
            return false
        }
    }

    /// Sort key for displaying descendant ranks in a sensible top-down order.
    var sortOrder: Int {
        switch self {
        case .domain:        return 0
        case .superkingdom:  return 1
        case .kingdom:       return 2
        case .subkingdom:    return 3
        case .infrakingdom:  return 4
        case .phylum:        return 5
        case .subphylum:     return 6
        case .superclass:    return 7
        case .class:         return 8
        case .subclass:      return 9
        case .infraclass:    return 10
        case .superorder:    return 11
        case .order:         return 12
        case .suborder:      return 13
        case .infraorder:    return 14
        case .superfamily:   return 15
        case .family:        return 16
        case .subfamily:     return 17
        case .tribe:         return 18
        case .subtribe:      return 19
        case .genus:         return 20
        case .subgenus:      return 21
        case .section:       return 22
        case .subsection:    return 23
        case .series:        return 24
        case .species:       return 25
        case .subspecies:    return 26
        case .variety:       return 27
        case .form:          return 28
        case .unranked:      return 100
        case .other:         return 101
        }
    }
}
