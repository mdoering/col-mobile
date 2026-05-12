import SwiftUI
import UIKit

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
                    Divider()
                    contactsSection
                    versionFooter
                }
                .padding()
            }
            .navigationTitle("About")
        }
    }

    private var versionFooter: some View {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return Text("Version \(version) (\(build))")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)
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
                Text("Release").font(.callout)
                Spacer()
                ReleasePicker()
            }
            HStack {
                Text("Common-name language").font(.callout)
                Spacer()
                PreferredLanguagePicker()
            }
        }
    }

    @ViewBuilder
    private var releaseMetadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected release").font(.headline)
            if let dataset = appState.selectedDataset {
                meta("Title", dataset.title)
                meta("Alias", dataset.alias)
                meta("Version", dataset.version)
                meta("Issued", dataset.issued)
                meta("Origin", dataset.origin)
                meta("Publisher", dataset.publisher)
                licenseRow(dataset.license)
                doiRow(dataset.doi)
                citationRow(dataset.citation)
            } else {
                Text("Loading release information…").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func licenseRow(_ license: String?) -> some View {
        if let license, !license.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("License").font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                if license.lowercased().contains("cc by") {
                    Image("CCBYIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 18)
                        .accessibilityLabel(license.uppercased())
                }
                Text(license.uppercased()).font(.callout)
            }
        }
    }

    @ViewBuilder
    private func doiRow(_ doi: String?) -> some View {
        if let doi, !doi.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DOI").font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Link(doi, destination: URL(string: "https://doi.org/\(doi)")!).font(.callout)
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = doi
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("Copy DOI")
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private func citationRow(_ citation: String?) -> some View {
        if let citation, !citation.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Citation").font(.caption).foregroundStyle(.secondary)
                HTMLText(html: citation)
                    .font(.caption)
                    .textSelection(.enabled)
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

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact & Follow").font(.headline)
            Link(destination: URL(string: "mailto:support@catalogueoflife.org")!) {
                Label("support@catalogueoflife.org", systemImage: "envelope")
                    .font(.callout)
            }
            Link(destination: URL(string: "https://www.linkedin.com/company/catalogue-of-life/")!) {
                Label("LinkedIn", systemImage: "link")
                    .font(.callout)
            }
        }
    }
}
