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
            // Phylopic silhouettes ship as solid-black SVGs. Render as a template
            // so .foregroundStyle (.primary by default) gives us black-on-light /
            // white-on-dark instead of an invisible black blob on the dark theme.
            Image("Groups/\(resolved.name)")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.primary)
                .accessibilityLabel(resolved.description ?? resolved.name)
        } else {
            EmptyView()
        }
    }
}
