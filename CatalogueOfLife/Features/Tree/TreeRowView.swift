import SwiftUI

struct TreeRowView: View {
    let node: TreeNode

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Note: /tree endpoint doesn't return a `group` field today, so this renders nothing.
            // Slot is kept for the future enrichment.
            GroupIcon(code: nil, size: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(node.name).italic().font(.body)
                    if let auth = node.authorship {
                        Text(auth).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(node.rank.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                }
                HStack(spacing: 8) {
                    if !node.isLeaf {
                        Label("\(node.childCount)", systemImage: "chevron.right.2")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("\(node.count) descendants")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
    }
}
