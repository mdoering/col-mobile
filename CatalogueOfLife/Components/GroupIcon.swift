import SwiftUI

/// Renders a TaxGroup icon for an API group code. Looks the code up in
/// the environment-injected `TaxGroupVocab` and resolves to the bundled SVG asset
/// under `Assets.xcassets/Groups/<vocabEntry.name>.imageset`. Renders nothing for
/// nil or unknown codes.
struct GroupIcon: View {
    @Environment(TaxGroupVocab.self) private var vocab
    let code: String?
    var size: CGFloat = 20

    var body: some View {
        if let resolved = vocab.lookup(code: code) {
            Image("Groups/\(resolved.name)")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(resolved.description ?? resolved.name)
        } else {
            EmptyView()
        }
    }
}
