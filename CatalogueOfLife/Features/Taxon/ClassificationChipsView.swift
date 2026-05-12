import SwiftUI

struct ClassificationChipsView: View {
    let items: [ClassificationItem]
    let onSelect: (ClassificationItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items) { item in
                    Button { onSelect(item) } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.rank.rawValue.uppercased())
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(item.name).font(.caption).italic()
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}
