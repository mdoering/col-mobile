import SwiftUI

struct AboutView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introSection
                    Divider()
                    identifiersSection
                    Divider()
                    preferencesSection
                    Divider()
                    releaseMetadataSection
                }
                .padding()
            }
            .navigationTitle("About")
            .toolbar { ToolbarItem(placement: .principal) { ReleasePicker() } }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("CoLLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .accessibilityLabel("Catalogue of Life")
            Text("""
            The Catalogue of Life (CoL) is the most comprehensive and authoritative \
            global index of species. It combines hundreds of taxonomic sources into a \
            single, unified checklist of every named living and recently extinct organism.
            """)
                .font(.callout)
            Link("www.catalogueoflife.org", destination: URL(string: "https://www.catalogueoflife.org")!)
                .font(.callout)
        }
    }

    private var identifiersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Identifiers").font(.headline)
            Text("""
            Each taxon in CoL has a short alphanumeric identifier (e.g. COL:CS5HF). \
            Identifiers in the latest extended release (3LXR) and the base release (3LR) \
            are stable and tracked by GBIF. Identifiers in older annual releases differ \
            and may not resolve elsewhere.
            """)
                .font(.callout)
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferences").font(.headline)
            HStack {
                Text("Common-name language").font(.callout)
                Spacer()
                PreferredLanguagePicker()
            }
        }
    }

    @ViewBuilder
    private var releaseMetadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected release").font(.headline)
            if let dataset = appState.selectedDataset {
                meta("Title", dataset.title)
                meta("Alias", dataset.alias)
                meta("Version", dataset.version)
                meta("Issued", dataset.issued)
                meta("Origin", dataset.origin)
                meta("Key", "\(dataset.key)")
                if let citation = dataset.citation {
                    Text("Citation").font(.subheadline).bold()
                    Text(citation).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Loading release information…").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func meta(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Text(value).font(.callout)
            }
        }
    }
}
