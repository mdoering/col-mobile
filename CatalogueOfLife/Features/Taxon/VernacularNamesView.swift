import SwiftUI

struct VernacularNamesView: View {
    let names: [VernacularName]
    let preferredLanguage: String?

    @State private var expanded = false

    /// Names to show by default: preferred language + English. Preserves existing sort.
    private var defaultVisible: [VernacularName] {
        sorted.filter { v in
            v.language == preferredLanguage || v.language == "eng"
        }
    }

    private var sorted: [VernacularName] {
        guard let lang = preferredLanguage else { return names }
        return names.sorted { a, b in
            (a.language == lang ? 0 : 1) < (b.language == lang ? 0 : 1)
        }
    }

    var body: some View {
        if names.isEmpty {
            EmptyView()
        } else {
            let visible = expanded ? sorted : defaultVisible
            VStack(alignment: .leading, spacing: 6) {
                Text("Common names").font(.headline)
                if visible.isEmpty {
                    // No preferred + no English — show first entry as a teaser to give the user something to expand from.
                    if let first = sorted.first {
                        row(first)
                    }
                } else {
                    ForEach(visible) { v in row(v) }
                }
                if names.count > visible.count {
                    Button {
                        expanded.toggle()
                    } label: {
                        Text(expanded ? "Show fewer" : "Show all \(names.count) names")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 4)
                }
            }
        }
    }

    private func row(_ v: VernacularName) -> some View {
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
