import SwiftUI
import Observation

@MainActor
@Observable
final class SuggestFieldViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded([TaxonSuggestion])
        case failed(APIError)
    }

    var query: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var state: LoadState = .idle

    private let client: APIClient
    private let getDatasetKey: @MainActor () -> Int?
    private var debounceTask: Task<Void, Never>?

    var debounceMillis: Int = 300

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?) {
        self.client = client
        self.getDatasetKey = getDatasetKey
    }

    private func scheduleSearch() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { state = .idle; return }
        let delay = debounceMillis
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            guard !Task.isCancelled, let self else { return }
            await run(query: trimmed)
        }
    }

    private func run(query: String) async {
        guard let key = getDatasetKey() else { state = .failed(.server(status: -1)); return }
        state = .loading
        do {
            let s = try await client.suggest(datasetKey: key, q: query)
            state = .loaded(s)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}

struct SuggestField: View {
    @State private var vm: SuggestFieldViewModel
    let onPick: (TaxonSuggestion) -> Void

    init(client: APIClient, getDatasetKey: @escaping @MainActor () -> Int?, onPick: @escaping (TaxonSuggestion) -> Void) {
        self._vm = State(initialValue: SuggestFieldViewModel(client: client, getDatasetKey: getDatasetKey))
        self.onPick = onPick
    }

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 0) {
            TextField("Jump to taxon", text: $vm.query)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal)
                .padding(.vertical, 6)
            if case let .loaded(suggestions) = vm.state, !suggestions.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions.prefix(10)) { s in
                            Button {
                                vm.query = ""
                                onPick(s)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    GroupIcon(code: s.group, size: 18)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(s.suggestion).font(.caption)
                                        if let ctx = s.context {
                                            Text(ctx).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.horizontal).padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 280)
                .background(.thinMaterial)
            }
        }
    }
}
