import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Compact count formatting")
struct CompactCountTests {
    /// Local decimal separator (e.g. "." on en_US, "," on de_DE) — the formatter
    /// follows the user's locale, so the tests follow it too.
    private static let dec = Locale.current.decimalSeparator ?? "."

    @Test("Below 1000 stays as a plain integer with no grouping")
    func belowThreshold() {
        #expect(GBIFSectionView.compactCount(0) == "0")
        #expect(GBIFSectionView.compactCount(7) == "7")
        #expect(GBIFSectionView.compactCount(999) == "999")
    }

    @Test("Thousands abbreviate with lowercase k")
    func thousands() {
        #expect(GBIFSectionView.compactCount(1_000) == "1k")
        #expect(GBIFSectionView.compactCount(1_234) == "1\(Self.dec)2k")
        #expect(GBIFSectionView.compactCount(45_000) == "45k")
    }

    @Test("Millions abbreviate with uppercase M")
    func millions() {
        #expect(GBIFSectionView.compactCount(1_000_000) == "1M")
        #expect(GBIFSectionView.compactCount(4_500_000) == "4\(Self.dec)5M")
    }

    @Test("Billions abbreviate with uppercase B")
    func billions() {
        #expect(GBIFSectionView.compactCount(1_000_000_000) == "1B")
    }
}
