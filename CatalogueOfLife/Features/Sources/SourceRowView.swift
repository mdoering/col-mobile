import SwiftUI

struct SourceRowView: View {
    let source: Source

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            logo
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title).font(.body).lineLimit(2)
                if let alias = source.alias {
                    Text(alias).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var logo: some View {
        if let url = source.logoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                default: placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "books.vertical").foregroundStyle(.secondary))
    }
}
