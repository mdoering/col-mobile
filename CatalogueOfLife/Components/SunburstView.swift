import SwiftUI

struct SunburstView: View {
    let root: SunburstNode
    /// Max number of rings beyond the center. Default 2.
    var maxDepth: Int = 2
    /// Tap handler: receives the tapped node (center disk taps are ignored).
    var onSelect: (SunburstNode) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = size / 2 * 0.95
            let innerRadius = outerRadius * 0.25
            let ringThickness = (outerRadius - innerRadius) / CGFloat(maxDepth)

            ZStack {
                Canvas { context, _ in
                    SunburstMath.draw(
                        root: root,
                        center: center,
                        innerRadius: innerRadius,
                        ringThickness: ringThickness,
                        maxDepth: maxDepth,
                        context: &context
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sunburst diagram")
                .frame(width: size, height: size)
                .contentShape(Circle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        if let hit = SunburstMath.hitTest(
                            point: value.location,
                            center: center,
                            innerRadius: innerRadius,
                            ringThickness: ringThickness,
                            root: root,
                            maxDepth: maxDepth
                        ) {
                            onSelect(hit)
                        }
                    }
                )
                Text(root.label)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: innerRadius * 1.6)
                    .multilineTextAlignment(.center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

enum SunburstMath {

    /// Sweep (radians) of a child within its parent's sweep, weighted by `count`.
    static func childSweep(child: SunburstNode, siblingsTotal: Int, parentSweep: Double) -> Double {
        guard siblingsTotal > 0 else { return 0 }
        return parentSweep * Double(child.count) / Double(siblingsTotal)
    }

    /// Walk + draw. depth 1 = first ring beyond center.
    static func draw(
        root: SunburstNode,
        center: CGPoint,
        innerRadius: CGFloat,
        ringThickness: CGFloat,
        maxDepth: Int,
        context: inout GraphicsContext
    ) {
        let total = max(root.children.reduce(0) { $0 + $1.count }, 1)
        drawChildren(
            parent: root,
            startAngle: -Double.pi / 2,
            sweep: 2 * .pi,
            siblingsTotal: total,
            depth: 1,
            center: center,
            innerRadius: innerRadius,
            ringThickness: ringThickness,
            maxDepth: maxDepth,
            context: &context
        )
    }

    private static func drawChildren(
        parent: SunburstNode,
        startAngle: Double,
        sweep: Double,
        siblingsTotal: Int,
        depth: Int,
        center: CGPoint,
        innerRadius: CGFloat,
        ringThickness: CGFloat,
        maxDepth: Int,
        context: inout GraphicsContext
    ) {
        guard depth <= maxDepth else { return }
        var cursor = startAngle
        for (idx, child) in parent.children.enumerated() {
            let childSweepValue = SunburstMath.childSweep(child: child, siblingsTotal: siblingsTotal, parentSweep: sweep)
            drawArc(
                center: center,
                innerR: innerRadius + CGFloat(depth - 1) * ringThickness,
                outerR: innerRadius + CGFloat(depth) * ringThickness,
                startAngle: cursor,
                endAngle: cursor + childSweepValue,
                color: arcColor(depth: depth, index: idx, total: parent.children.count),
                context: &context
            )
            if !child.children.isEmpty {
                let grandTotal = max(child.children.reduce(0) { $0 + $1.count }, 1)
                drawChildren(
                    parent: child,
                    startAngle: cursor,
                    sweep: childSweepValue,
                    siblingsTotal: grandTotal,
                    depth: depth + 1,
                    center: center,
                    innerRadius: innerRadius,
                    ringThickness: ringThickness,
                    maxDepth: maxDepth,
                    context: &context
                )
            }
            cursor += childSweepValue
        }
    }

    private static func drawArc(
        center: CGPoint,
        innerR: CGFloat,
        outerR: CGFloat,
        startAngle: Double,
        endAngle: Double,
        color: Color,
        context: inout GraphicsContext
    ) {
        var path = Path()
        path.addArc(center: center, radius: outerR,
                    startAngle: Angle(radians: startAngle),
                    endAngle: Angle(radians: endAngle), clockwise: false)
        path.addArc(center: center, radius: innerR,
                    startAngle: Angle(radians: endAngle),
                    endAngle: Angle(radians: startAngle), clockwise: true)
        path.closeSubpath()
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 0.5)
    }

    private static func arcColor(depth: Int, index: Int, total: Int) -> Color {
        let hue = Double(index) / Double(max(total, 1))
        let saturation = depth == 1 ? 0.55 : 0.40
        let brightness = depth == 1 ? 0.85 : 0.75
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Returns the deepest hit node at `point`, or nil if outside.
    static func hitTest(
        point: CGPoint,
        center: CGPoint,
        innerRadius: CGFloat,
        ringThickness: CGFloat,
        root: SunburstNode,
        maxDepth: Int
    ) -> SunburstNode? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = (dx * dx + dy * dy).squareRoot()
        guard radius >= innerRadius else { return nil }
        let outerR = innerRadius + CGFloat(maxDepth) * ringThickness
        guard radius <= outerR else { return nil }
        let depth = Int(((radius - innerRadius) / ringThickness)) + 1
        guard depth >= 1, depth <= maxDepth else { return nil }
        var angle = atan2(Double(dy), Double(dx))
        angle += .pi / 2
        if angle < 0 { angle += 2 * .pi }
        return descend(parent: root, parentSweepStart: 0, parentSweepEnd: 2 * .pi, depth: 1, targetDepth: depth, targetAngle: angle)
    }

    private static func descend(
        parent: SunburstNode,
        parentSweepStart: Double,
        parentSweepEnd: Double,
        depth: Int,
        targetDepth: Int,
        targetAngle: Double
    ) -> SunburstNode? {
        let totalChildren = max(parent.children.reduce(0) { $0 + $1.count }, 1)
        let parentSweep = parentSweepEnd - parentSweepStart
        var cursor = parentSweepStart
        for child in parent.children {
            let childSweepValue = SunburstMath.childSweep(child: child, siblingsTotal: totalChildren, parentSweep: parentSweep)
            let childEnd = cursor + childSweepValue
            if targetAngle >= cursor, targetAngle < childEnd {
                if depth == targetDepth {
                    return child
                }
                return descend(parent: child,
                                parentSweepStart: cursor,
                                parentSweepEnd: childEnd,
                                depth: depth + 1,
                                targetDepth: targetDepth,
                                targetAngle: targetAngle)
            }
            cursor = childEnd
        }
        return nil
    }
}
