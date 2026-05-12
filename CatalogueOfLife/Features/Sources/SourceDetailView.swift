import SwiftUI

struct SourceDetailView: View {
    @Environment(AppState.self) private var appState
    let sourceKey: Int
    @State private var state: LoadState = .loading

    enum LoadState: Equatable {
        case loading
        case loaded(Source)
        case failed(APIError)
    }

    var body: some View {
        content
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
    }

    private func load() async {
        guard let key = appState.selectedDataset?.key else {
            state = .failed(.server(status: -1))
            return
        }
        state = .loading
        do {
            let source = try await APIClientLive().getSource(datasetKey: key, sourceKey: sourceKey)
            state = .loaded(source)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loaded(let source):
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SourceRowView(source: source)
                    if let citation = source.citation {
                        section("Citation") { Text(citation).font(.callout) }
                    }
                    if let description = source.description {
                        section("Description") { Text(description).font(.callout) }
                    }
                    metadata(source)
                }
                .padding()
            }
        case .failed(let err):
            ContentUnavailableView("Couldn't load source",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text(String(describing: err)))
        case .loading:
            ProgressView()
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }

    @ViewBuilder
    private func metadata(_ source: Source) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            metaRow("Version", source.version)
            metaRow("Issued", source.issued)
            metaRow("License", source.license)
            metaRow("Taxonomic scope", source.taxonomicScope)
            metaRow("Geographic scope", source.geographicScope)
            metaRow("DOI", source.doi)
            if let url = source.websiteURL {
                Link(url.absoluteString, destination: url).font(.callout)
            }
        }
    }

    @ViewBuilder
    private func metaRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
                Text(value).font(.callout)
            }
        }
    }
}
