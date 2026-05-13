import SwiftUI

struct TypeMaterialView: View {
    let entries: [TypeMaterialEntry]

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Type material").font(.headline)
                ForEach(entries) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            if let status = e.status {
                                Text(status.capitalized)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(.tint.opacity(0.15), in: Capsule())
                            }
                            if let inst = e.institutionCode {
                                Text(inst).font(.caption.monospaced())
                            }
                            if let cat = e.catalogNumber {
                                Text(cat).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        if let citation = e.citation {
                            Text(citation).font(.caption).foregroundStyle(.secondary)
                        }
                        if let link = e.link {
                            Link(link.absoluteString, destination: link).font(.caption2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
