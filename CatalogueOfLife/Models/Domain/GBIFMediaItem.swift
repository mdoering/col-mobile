import Foundation

struct GBIFMediaItem: Equatable, Hashable, Identifiable, Sendable {
    /// Stable id synthesized from the image URL (so SwiftUI ForEach works without duplicates).
    let id: String
    let imageURL: URL
    let sourceURL: URL?
    let creator: String?
    let publisher: String?
    let license: String?
    let rightsHolder: String?
    /// Carried over from the parent occurrence so the fullscreen viewer can
    /// caption the image with the recorded identification + place + date.
    let occurrenceName: String?
    let occurrenceCountry: String?
    let occurrenceDate: String?
    /// GBIF occurrence id — used to deep-link to www.gbif.org/occurrence/<id>.
    let gbifID: String?

    var occurrenceURL: URL? {
        guard let gbifID, !gbifID.isEmpty else { return nil }
        return URL(string: "https://www.gbif.org/occurrence/\(gbifID)")
    }
}

extension GBIFMediaItem {
    /// Flatten an `OccurrenceWithMediaDTO` into a list of items, keeping only entries
    /// whose `type` is `"StillImage"` and which have a parseable image URL.
    static func from(dto: OccurrenceWithMediaDTO) -> [GBIFMediaItem] {
        var seen = Set<String>()
        var out: [GBIFMediaItem] = []
        for result in dto.results {
            for media in result.media ?? [] {
                guard (media.type ?? "").localizedCaseInsensitiveCompare("StillImage") == .orderedSame else { continue }
                guard let raw = media.identifier, let url = URL(string: raw) else { continue }
                let key = raw
                if seen.contains(key) { continue }
                seen.insert(key)
                out.append(GBIFMediaItem(
                    id: key,
                    imageURL: url,
                    sourceURL: media.references.flatMap(URL.init(string:)),
                    creator: media.creator,
                    publisher: media.publisher,
                    license: media.license,
                    rightsHolder: media.rightsHolder,
                    occurrenceName: result.scientificName,
                    occurrenceCountry: result.country,
                    occurrenceDate: result.eventDate,
                    gbifID: result.gbifID
                ))
            }
        }
        return out
    }
}
