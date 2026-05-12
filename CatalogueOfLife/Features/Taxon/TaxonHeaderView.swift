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
