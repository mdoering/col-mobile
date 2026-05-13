import SwiftUI
import Observation

@MainActor
@Observable
final class FeedbackViewModel {
    enum SubmitState: Equatable {
        case editing
        case submitting
        case submitted(URL)
        case failed(APIError)
    }

    var message: String = ""
    private(set) var state: SubmitState = .editing

    private let client: APIClient
    private let datasetKey: Int
    private let taxonId: String
    private let email: String

    init(client: APIClient, datasetKey: Int, taxonId: String, userEmail: String) {
        self.client = client
        self.datasetKey = datasetKey
        self.taxonId = taxonId
        self.email = userEmail
    }

    var isValid: Bool {
        let trimmedMsg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedMsg.count >= 5
    }

    func submit() async {
        state = .submitting
        do {
            let url = try await client.submitFeedback(
                datasetKey: datasetKey,
                taxonId: taxonId,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            state = .submitted(url)
        } catch let err as APIError {
            state = .failed(err)
        } catch {
            state = .failed(.server(status: -1))
        }
    }
}

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: FeedbackViewModel
    let scientificName: String

    init(datasetKey: Int, taxonId: String, scientificName: String, userEmail: String) {
        self._vm = State(initialValue: FeedbackViewModel(
            client: APIClientLive(),
            datasetKey: datasetKey,
            taxonId: taxonId,
            userEmail: userEmail
        ))
        self.scientificName = scientificName
    }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                Section {
                    Text("Report a data issue for ") + Text(scientificName).italic()
                } header: {
                    Text("Taxon")
                } footer: {
                    Text("Your message will be posted as a public GitHub issue at github.com/CatalogueOfLife/data.")
                }
                Section {
                    TextField("What's wrong?", text: $vm.message, axis: .vertical)
                        .lineLimit(4...10)
                        .disabled(vm.state == .submitting)
                } header: {
                    Text("Message")
                }

                resultSection
            }
            .navigationTitle("Send feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .submitted = vm.state {
                        Button("Done") { dismiss() }
                    } else {
                        Button {
                            Task { await vm.submit() }
                        } label: {
                            if vm.state == .submitting {
                                ProgressView()
                            } else {
                                Text("Send")
                            }
                        }
                        .disabled(!vm.isValid || vm.state == .submitting)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch vm.state {
        case .submitted(let url):
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Submitted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Link(url.absoluteString, destination: url)
                        .font(.caption.monospaced())
                }
            }
        case .failed(let err):
            Section {
                Label("Couldn't submit: \(String(describing: err))", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        case .editing, .submitting:
            EmptyView()
        }
    }
}
