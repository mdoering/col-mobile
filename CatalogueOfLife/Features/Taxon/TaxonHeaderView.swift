import SwiftUI
import UIKit

struct TaxonHeaderView: View {
    let info: TaxonInfo
    let preferredVernacular: VernacularName?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                nameText
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

    /// Concatenate the dagger (when extinct), scientific name, and authorship
    /// into a single Text so the wrap chooses the line break naturally —
    /// authorship folds onto a second line before the scientific name does,
    /// because Text wraps at word boundaries from the end. Each run keeps its
    /// own font/style via Text's `+` operator.
    @ViewBuilder
    private var nameText: some View {
        let dagger: Text = info.extinct
            ? Text("† ").font(.title2).bold()
            : Text("")
        let name = Text(info.scientificName).italic().font(.title2).bold()
        let combined: Text = {
            if let auth = info.authorship {
                return dagger + name + Text(" ") + Text(auth).font(.subheadline).foregroundStyle(.secondary)
            } else {
                return dagger + name
            }
        }()
        combined
            .textSelection(.enabled)
            .accessibilityLabel(info.extinct ? "Extinct, \(info.scientificName)" : info.scientificName)
    }
}
