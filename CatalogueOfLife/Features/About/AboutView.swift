import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    banner
                    releaseMetadataSection
                    introSection
                    Divider()
                    identifiersSection
                        .padding(.horizontal, 20)
                    Divider()
                    preferencesSection
                        .padding(.horizontal, 20)
                    versionFooter
                        .padding(.horizontal, 20)
                }
                .padding(.bottom)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .top)
        }
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.51, blue: 0.69),  // CoL blue (#1782b0)
                         Color(red: 0.03, green: 0.36, blue: 0.50)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                Image("CoLLogoWhite")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .padding(.bottom, 4)
                Text(headerTitle)
                    .font(.title3).bold()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.top, 80)         // leave room below the nav bar
            .padding(.bottom, 20)
        }
        .frame(height: 200)
    }

    private var headerTitle: String {
        if let alias = appState.selectedDataset?.alias, !alias.isEmpty {
            return "About \(alias)"
        }
        return "About"
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

    @ViewBuilder
    private var releaseMetadataSection: some View {
        if let dataset = appState.selectedDataset {
            VStack(alignment: .leading, spacing: 10) {
                doiRow(dataset.doi)
                meta("Version", dataset.version)
                licenseRow(dataset.license)
                meta("Publisher", dataset.publisher)
                citationRow(dataset: dataset)
            }
            .padding(.horizontal, 20)
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("""
            The Catalogue of Life (CoL) is the most comprehensive and authoritative \
            global index of species. It combines hundreds of taxonomic sources into a \
            single, unified checklist of every named living and recently extinct organism.
            """)
                .font(.callout)
            Link("www.catalogueoflife.org", destination: URL(string: "https://www.catalogueoflife.org")!)
                .font(.callout)
            Link("support@catalogueoflife.org", destination: URL(string: "mailto:support@catalogueoflife.org")!)
                .font(.callout)
            Link("LinkedIn", destination: URL(string: "https://www.linkedin.com/company/catalogue-of-life/")!)
                .font(.callout)
        }
        .padding(.horizontal, 20)
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
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 8) {
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
            HStack {
                Text("Your email").font(.callout)
                Spacer()
                TextField("you@example.com", text: Binding(
                    get: { appState.userEmail ?? "" },
                    set: { appState.userEmail = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 220)
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
    private func citationRow(dataset: DatasetRef) -> some View {
        if let citation = dataset.citation, !citation.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Citation").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = stripHTML(citation)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy citation")

                    Button {
                        Task { await copyBibTeX(datasetKey: dataset.key) }
                    } label: {
                        Image(systemName: "book.closed")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy BibTeX citation")
                }
                HTMLText(html: citation)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
    }

    private func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    private func copyBibTeX(datasetKey: Int) async {
        var request = URLRequest(url: URL(string: "https://api.checklistbank.org/dataset/\(datasetKey)")!)
        request.setValue("application/x-bibtex", forHTTPHeaderField: "Accept")
        if let (data, _) = try? await URLSession.shared.data(for: request),
           let text = String(data: data, encoding: .utf8), !text.isEmpty {
            UIPasteboard.general.string = text
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
