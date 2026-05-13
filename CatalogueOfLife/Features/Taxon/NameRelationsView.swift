import SwiftUI

struct NameRelationsView: View {
    let relations: [NameRelation]
    let onSelect: (String) -> Void  // related usageId → push detail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name relations").font(.headline)
            ForEach(relations) { rel in
                HStack(alignment: .firstTextBaseline) {
                    Text(rel.type.capitalized).font(.callout)
                    Spacer()
                    if let related = rel.relatedUsageId {
                        Button {
                            onSelect(related)
                        } label: {
                            Text("COL:\(related)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}
