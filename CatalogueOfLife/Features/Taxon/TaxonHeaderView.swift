import SwiftUI

struct TaxonHeaderView: View {
    let info: TaxonInfo
    let preferredVernacular: VernacularName?

    private var prefixedName: String {
        info.extinct ? "† \(info.scientificName)" : info.scientificName
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: info.group, size: 28)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(prefixedName).italic().font(.title2).bold()
                    if let auth = info.authorship {
                        Text(auth).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if info.merged {
                        Text("XR")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.purple.opacity(0.18), in: Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                if let v = preferredVernacular {
                    Text(v.name).font(.body).foregroundStyle(.secondary)
                }
                if info.status != .accepted {
                    Text(info.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
