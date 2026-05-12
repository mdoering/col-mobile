import SwiftUI

struct VernacularNamesView: View {
    let names: [VernacularName]
    let preferredLanguage: String?

    var sorted: [VernacularName] {
        guard let lang = preferredLanguage else { return names }
        return names.sorted { a, b in
            (a.language == lang ? 0 : 1) < (b.language == lang ? 0 : 1)
        }
    }

    var body: some View {
        if names.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Common names").font(.headline)
                ForEach(sorted) { v in
                    HStack {
                        Text(v.name)
                        Spacer()
                        if let lang = v.language {
                            Text(lang).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
