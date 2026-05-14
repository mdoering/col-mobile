import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("GBIFSectionViewModel")
@MainActor
struct GBIFSectionViewModelTests {

    @Test("Loads metrics + images successfully")
    func loadsBoth() async {
        let stub = StubGBIFClient()
        stub.metrics["T1"] = GBIFMetrics(occurrenceCount: 100, distinctCountries: 5, distinctDatasets: 3, topCountries: [("AU", 50)])
        stub.images["T1"] = [
            GBIFMediaItem(id: "u1", imageURL: URL(string: "https://example.org/1.jpg")!,
                          sourceURL: nil, creator: "A", publisher: nil, license: nil, rightsHolder: nil,
                          occurrenceName: nil, occurrenceCountry: nil, occurrenceDate: nil, gbifID: nil)
        ]
        let vm = GBIFSectionViewModel(client: stub)
        await vm.load(taxonId: "T1")
        #expect(vm.didLoad)
        #expect(vm.failed == false)
        #expect(vm.metrics?.occurrenceCount == 100)
        #expect(vm.images.count == 1)
    }

    @Test("Reports failed when both fetches fail")
    func failsBoth() async {
        let stub = StubGBIFClient()
        stub.error = .server(status: 503)
        let vm = GBIFSectionViewModel(client: stub)
        await vm.load(taxonId: "T1")
        #expect(vm.didLoad)
        #expect(vm.failed)
        #expect(vm.metrics == nil)
        #expect(vm.images.isEmpty)
    }

    @Test("Partial success: images load even if metrics fail")
    func partialSuccess() async {
        let stub = StubGBIFClient()
        // No metrics entry → throws .notFound; images present.
        stub.images["T1"] = [
            GBIFMediaItem(id: "u1", imageURL: URL(string: "https://example.org/1.jpg")!,
                          sourceURL: nil, creator: nil, publisher: nil, license: nil, rightsHolder: nil,
                          occurrenceName: nil, occurrenceCountry: nil, occurrenceDate: nil, gbifID: nil)
        ]
        let vm = GBIFSectionViewModel(client: stub)
        await vm.load(taxonId: "T1")
        #expect(vm.didLoad)
        #expect(vm.failed == false)
        #expect(vm.metrics == nil)
        #expect(vm.images.count == 1)
    }
}
