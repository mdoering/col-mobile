import SwiftUI

struct TaxonHeaderView: View {
    let info: TaxonInfo
    let preferredVernacular: VernacularName?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            GroupIcon(code: info.group, size: 28)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(info.scientificName).italic().font(.title2).bold()
                    if let auth = info.authorship {
                        Text(auth).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(info.rank.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                    if info.status != .accepted {
                        Text(info.status.rawValue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let v = preferredVernacular {
                    Text(v.name).font(.body).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
