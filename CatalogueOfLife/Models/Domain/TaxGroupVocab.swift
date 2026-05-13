import Foundation
import Observation

@MainActor
@Observable
final class TaxGroupVocab {
    private let byCode: [String: TaxGroup]

    init(groups: [TaxGroup]) {
        var map: [String: TaxGroup] = [:]
        for group in groups {
            // The API surfaces the vocab `name` on taxa (e.g. "chordates", "mammals"), so
            // index by name first.
            map[group.name] = group
            // Some endpoints/codes can still return one of the `codes` values
            // (bacterial / botanical / virus / zoological) — keep those mapped too.
            for code in group.codes {
                if map[code] == nil { map[code] = group }
            }
        }
        self.byCode = map
    }

    /// Looks up the canonical `TaxGroup` for the given API `group` code.
    func lookup(code: String?) -> TaxGroup? {
        guard let code, !code.isEmpty else { return nil }
        return byCode[code]
    }

    /// Loads the bundled vocab snapshot from the app bundle. Falls back to an empty
    /// vocab (no icons rendered) if the file is missing or unparseable.
    static func loadBundled() -> TaxGroupVocab {
        guard let url = Bundle.main.url(forResource: "taxgroup_vocab", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dtos = try? JSONDecoder().decode([TaxGroupVocabDTO].self, from: data) else {
            return TaxGroupVocab(groups: [])
        }
        return TaxGroupVocab(groups: dtos.map(TaxGroup.init(dto:)))
    }
}
