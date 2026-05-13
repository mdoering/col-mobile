import SwiftUI

struct SourceLinkView: View {
    let sourceDatasetKey: Int
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source").font(.headline)
            Button {
                onSelect()
            } label: {
                HStack {
                    Image(systemName: "books.vertical")
                    Text("View source dataset")
                    Spacer()
                    Image(systemName: "chevron.forward").font(.caption).foregroundStyle(.tertiary)
                }
                .font(.callout)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
    }
}
