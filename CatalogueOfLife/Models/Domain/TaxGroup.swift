import Foundation

/// One row of the TaxGroup vocabulary.
///
/// The API's `group` field on a taxon/search hit carries one of the `codes` strings.
/// The `name` field (e.g. "viruses") is the canonical group name and is what we use
/// as the bundled SVG asset name in `Assets.xcassets/Groups/<name>.imageset/`.
struct TaxGroup: Equatable, Hashable, Sendable {
    /// Strings that may appear as a `group` field on a taxon and route to this entry.
    let codes: [String]
    /// Canonical group name, used as the bundled image asset key.
    let name: String
    /// Human-readable description (English).
    let description: String?

    init(dto: TaxGroupVocabDTO) {
        self.codes = dto.codes
        self.name = dto.name
        self.description = dto.description
    }
}
