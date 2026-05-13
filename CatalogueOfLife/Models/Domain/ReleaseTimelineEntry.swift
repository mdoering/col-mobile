import Foundation

struct ReleaseTimelineEntry: Codable, Equatable, Identifiable, Sendable {
    let alias: String
    let displayName: String
    let datasetKey: Int?
    let issued: String?           // ISO date, e.g. "2025-06-13"
    let taxonCount: Int
    let nameCount: Int
    let synonymCount: Int
    let families: Int
    let genera: Int
    let species: Int

    var id: String { alias }

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
