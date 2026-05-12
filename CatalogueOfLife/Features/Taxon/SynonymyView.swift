import SwiftUI

struct SynonymyView: View {
    let groups: [SynonymyGroup]

    var body: some View {
        if groups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Synonymy").font(.headline)
                ForEach(groups) { group in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(group.entries) { entry in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(entry.scientificName).italic()
                                    if let auth = entry.authorship {
                                        Text(auth).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        HStack {
                            Text(group.kind == .homotypic ? "Homotypic" : "Heterotypic")
                                .font(.subheadline)
                            Text("(\(group.entries.count))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
