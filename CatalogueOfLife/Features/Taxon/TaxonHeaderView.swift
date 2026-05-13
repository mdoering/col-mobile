import SwiftUI
import UIKit

struct TaxonHeaderView: View {
    let info: TaxonInfo
    let preferredVernacular: VernacularName?

    var body: some View {
        // Group icon moved to the toolbar (top-right) — the header now leads
        // with the scientific name itself, so long names get the full width.
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if info.extinct {
                    Text("†")
                        .font(.title2).bold()
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Extinct")
                }
                Text(info.scientificName).italic().font(.title2).bold()
                    .textSelection(.enabled)
                if let auth = info.authorship {
                    Text(auth).font(.subheadline).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if info.merged {
                    Text("XR")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.purple.opacity(0.18), in: Capsule())
                        .foregroundStyle(.purple)
                }
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = info.scientificName
                } label: {
                    Label("Copy scientific name", systemImage: "doc.on.doc")
                }
                if let auth = info.authorship {
                    Button {
                        UIPasteboard.general.string = "\(info.scientificName) \(auth)"
                    } label: {
                        Label("Copy name with authorship", systemImage: "doc.on.doc.fill")
                    }
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
