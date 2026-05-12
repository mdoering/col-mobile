import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("FeedbackViewModel")
@MainActor
struct FeedbackViewModelTests {
    private func make() -> (FeedbackViewModel, StubAPIClient) {
        let stub = StubAPIClient()
        let vm = FeedbackViewModel(client: stub, datasetKey: 9837, taxonId: "T1")
        return (vm, stub)
    }

    @Test("isValid requires non-trivial message and an email-shaped string")
    func validation() {
        let (vm, _) = make()
        #expect(vm.isValid == false)
        vm.message = "hi"
        vm.email = "a@b.com"
        #expect(vm.isValid == false)        // message too short
        vm.message = "Detailed report"
        vm.email = "not-an-email"
        #expect(vm.isValid == false)        // bad email
        vm.email = "a@b.co"
        #expect(vm.isValid == true)
    }

    @Test("Successful submit transitions state to .submitted with returned URL")
    func submitsSuccess() async {
        let (vm, stub) = make()
        stub.feedbackResult = URL(string: "https://github.com/CatalogueOfLife/data/issues/42")!
        vm.message = "Genus typo"
        vm.email = "you@example.com"
        await vm.submit()
        if case let .submitted(url) = vm.state {
            #expect(url.absoluteString == "https://github.com/CatalogueOfLife/data/issues/42")
        } else {
            Issue.record("Expected .submitted; got \(vm.state)")
        }
    }

    @Test("Server error surfaces as .failed")
    func submitFails() async {
        let (vm, stub) = make()
        stub.error = .server(status: 500)
        vm.message = "Some detailed message"
        vm.email = "you@example.com"
        await vm.submit()
        #expect(vm.state == .failed(.server(status: 500)))
    }
}
