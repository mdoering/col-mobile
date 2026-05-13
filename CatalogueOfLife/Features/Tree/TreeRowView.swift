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
                    Spacer(minLength: 8)
                    Text(node.rank.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                }
                if node.authorship != nil || node.count > 0 {
                    HStack(alignment: .firstTextBaseline) {
                        if let auth = node.authorship {
                            Text(auth).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if node.count > 0 {
                            Text("\(node.count) descendants")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }
}
