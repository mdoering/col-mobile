import Foundation

struct ReleaseTimelineEntry: Codable, Equatable, Identifiable, Sendable {
    let alias: String
    let displayName: String
    let datasetKey: Int?
    let issued: String?           // ISO date, e.g. "2025-06-13"
    let origin: String            // "release" or "xrelease"
    let taxonCount: Int
    let nameCount: Int
    let synonymCount: Int
    let families: Int
    let genera: Int
    let species: Int

    var id: String { "\(origin):\(alias)" }

    /// Parses the ISO date into a `Date` (date-only). Returns nil if unparseable.
    var issuedDate: Date? {
        guard let issued else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: issued)
    }

    // Custom decoder to default `origin` to "release" when reading older JSON
    // that predates the field (e.g. from a cached bundle).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alias        = try c.decode(String.self, forKey: .alias)
        displayName  = try c.decode(String.self, forKey: .displayName)
        datasetKey   = try c.decodeIfPresent(Int.self, forKey: .datasetKey)
        issued       = try c.decodeIfPresent(String.self, forKey: .issued)
        origin       = try c.decodeIfPresent(String.self, forKey: .origin) ?? "release"
        taxonCount   = try c.decode(Int.self, forKey: .taxonCount)
        nameCount    = try c.decode(Int.self, forKey: .nameCount)
        synonymCount = try c.decode(Int.self, forKey: .synonymCount)
        families     = try c.decode(Int.self, forKey: .families)
        genera       = try c.decode(Int.self, forKey: .genera)
        species      = try c.decode(Int.self, forKey: .species)
    }
}

enum ReleaseTimeline {
    /// Reads the bundled timeline snapshot from the app bundle. Returns an empty array
    /// if the file is missing or unparseable.
    static func loadBundled() -> [ReleaseTimelineEntry] {
        guard let url = Bundle.main.url(forResource: "release_timeline", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ReleaseTimelineEntry].self, from: data)
        else {
            return []
        }
        return entries
    }
}
