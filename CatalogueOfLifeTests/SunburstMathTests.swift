import Testing
import Foundation
@testable import CatalogueOfLife

@Suite("Sunburst math")
struct SunburstMathTests {
    private func node(_ id: String, count: Int, _ children: [SunburstNode] = []) -> SunburstNode {
        SunburstNode(id: id, label: id, count: count, children: children)
    }

    @Test("Equal-count children get equal sweeps")
    func equalCountSweeps() {
        let sweep1 = SunburstMath.childSweep(child: node("A", count: 10), siblingsTotal: 30, parentSweep: .pi)
        let sweep2 = SunburstMath.childSweep(child: node("B", count: 10), siblingsTotal: 30, parentSweep: .pi)
        let sweep3 = SunburstMath.childSweep(child: node("C", count: 10), siblingsTotal: 30, parentSweep: .pi)
        #expect((sweep1 + sweep2 + sweep3).isApproximately(.pi))
        #expect(sweep1.isApproximately(.pi / 3))
    }

    @Test("Weighted children get proportional sweeps")
    func weightedSweeps() {
        let total = 100
        let big = SunburstMath.childSweep(child: node("Big", count: 80), siblingsTotal: total, parentSweep: 2 * .pi)
        let small = SunburstMath.childSweep(child: node("Small", count: 20), siblingsTotal: total, parentSweep: 2 * .pi)
        #expect(big.isApproximately(2 * .pi * 0.8))
        #expect(small.isApproximately(2 * .pi * 0.2))
    }

    @Test("Hit-test inside inner radius returns nil")
    func hitTestCenter() {
        let root = node("R", count: 10, [node("A", count: 10)])
        let result = SunburstMath.hitTest(
            point: CGPoint(x: 100, y: 100),
            center: CGPoint(x: 100, y: 100),
            innerRadius: 30, ringThickness: 30, root: root, maxDepth: 2
        )
        #expect(result == nil)
    }

    @Test("Hit-test outside outer radius returns nil")
    func hitTestOutside() {
        let root = node("R", count: 10, [node("A", count: 10)])
        let result = SunburstMath.hitTest(
            point: CGPoint(x: 1000, y: 1000),
            center: CGPoint(x: 100, y: 100),
            innerRadius: 30, ringThickness: 30, root: root, maxDepth: 2
        )
        #expect(result == nil)
    }

    @Test("Hit-test on ring 1 returns a direct child")
    func hitTestRing1() {
        let onlyChild = node("Only", count: 10)
        let root = node("R", count: 10, [onlyChild])
        let result = SunburstMath.hitTest(
            point: CGPoint(x: 100, y: 50),     // straight up from center
            center: CGPoint(x: 100, y: 100),
            innerRadius: 30, ringThickness: 30, root: root, maxDepth: 2
        )
        #expect(result?.id == "Only")
    }
}

private extension Double {
    func isApproximately(_ other: Double, tolerance: Double = 1e-9) -> Bool {
        abs(self - other) < tolerance
    }
}
