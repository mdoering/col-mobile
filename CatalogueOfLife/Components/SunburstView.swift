import SwiftUI

struct SunburstView: View {
    let root: SunburstNode
    /// Max number of rings beyond the center. Default 2.
    var maxDepth: Int = 2
    /// Controls what the popover fetches and what "Tap to open" navigates to.
    var popoverKind: PopoverKind = .taxon
    /// When true, draws labels for every arc whose chord fits the text (no minimum-sweep cutoff).
    /// Use in the full-screen / zoomed view; leave off for the inline view to avoid clutter.
    var alwaysShowLabels: Bool = false
    /// Tap handler: receives the selected node (via the popover's Open button).
    var onSelect: (SunburstNode) -> Void = { _ in }

    enum PopoverKind {
        /// Metrics from /taxon/{id}/metrics; tap → navigate to that taxon.
        case taxon
        /// Metrics from /nameusage/search?group=…; tap → apply group filter in Search.
        case group
    }

    @State private var popoverNode: SunburstNode?

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
                        alwaysShowLabels: alwaysShowLabels,
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
                            popoverNode = hit
                        }
                    }
                )
                .popover(item: $popoverNode) { node in
                    SunburstPopover(node: node, kind: popoverKind) {
                        popoverNode = nil
                        onSelect(node)
                    }
                    .presentationCompactAdaptation(.popover)
                }

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

private struct SunburstPopover: View {
    @Environment(AppState.self) private var appState
    let node: SunburstNode
    let kind: SunburstView.PopoverKind
    let onTap: () -> Void

    @State private var taxonMetrics: TaxonMetrics?
    @State private var groupMetrics: GroupBreakdownMetrics?
    @State private var loaded = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(node.label).italic().font(.headline)
                if let rank = node.rank {
                    Text(rank.rawValue.capitalized).font(.caption2).foregroundStyle(.secondary)
                }
                if loaded {
                    metricRows
                } else {
                    HStack { ProgressView().controlSize(.small); Text("Loading…").font(.caption2) }
                }
                Text("Tap to open").font(.caption2).foregroundStyle(.tertiary).padding(.top, 4)
            }
            .padding()
            .frame(minWidth: 200, alignment: .leading)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .task(id: node.id) {
            loaded = false
            guard let key = appState.selectedDataset?.key else { loaded = true; return }
            switch kind {
            case .taxon:
                taxonMetrics = try? await APIClientLive().getTaxonMetrics(datasetKey: key, taxonId: node.id)
            case .group:
                groupMetrics = try? await APIClientLive().getGroupMetrics(datasetKey: key, group: node.label)
            }
            loaded = true
        }
    }

    @ViewBuilder
    private var metricRows: some View {
        switch kind {
        case .taxon:
            if let m = taxonMetrics {
                metricRow("All taxa", m.taxonCount)
                if showRank(.family), let n = m.taxaByRankCount[.family], n > 0 { metricRow("Families", n) }
                if showRank(.genus), let n = m.taxaByRankCount[.genus], n > 0 { metricRow("Genera", n) }
                if showRank(.species), let n = m.taxaByRankCount[.species], n > 0 { metricRow("Species", n) }
                if m.sourceCount > 0 { metricRow("Sources", m.sourceCount) }
            }
        case .group:
            if let m = groupMetrics {
                metricRow("All names", m.total)
                if let n = m.taxaByRank[.family], n > 0 { metricRow("Families", n) }
                if let n = m.taxaByRank[.genus], n > 0 { metricRow("Genera", n) }
                if let n = m.taxaByRank[.species], n > 0 { metricRow("Species", n) }
            }
        }
    }

    /// Show a rank's metric only if it's strictly below this taxon's rank.
    /// Without a known node rank, show all (no gating).
    private func showRank(_ candidate: Rank) -> Bool {
        guard let nodeRank = node.rank else { return true }
        return candidate.sortOrder > nodeRank.sortOrder
    }

    @ViewBuilder
    private func metricRow(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).font(.caption)
            Spacer(minLength: 12)
            Text(value, format: .number).font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
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
        alwaysShowLabels: Bool = false,
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
            alwaysShowLabels: alwaysShowLabels,
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
        alwaysShowLabels: Bool,
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
            // Sweep threshold protects the inline view from label spam; full-screen view
            // opts out via `alwaysShowLabels`. drawArcLabel still skips when the chord is
            // too narrow to fit the text.
            let minLabelSweep: Double = alwaysShowLabels ? 0 : .pi / 18
            if childSweepValue >= minLabelSweep {
                drawArcLabel(
                    text: child.label,
                    center: center,
                    innerR: innerRadius + CGFloat(depth - 1) * ringThickness,
                    outerR: innerRadius + CGFloat(depth) * ringThickness,
                    startAngle: cursor,
                    endAngle: cursor + childSweepValue,
                    context: &context
                )
            }
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
                    alwaysShowLabels: alwaysShowLabels,
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

    private static func drawArcLabel(
        text: String,
        center: CGPoint,
        innerR: CGFloat,
        outerR: CGFloat,
        startAngle: Double,
        endAngle: Double,
        context: inout GraphicsContext
    ) {
        let midAngle = (startAngle + endAngle) / 2
        let midRadius = (innerR + outerR) / 2
        let x = center.x + cos(midAngle) * midRadius
        let y = center.y + sin(midAngle) * midRadius

        var attr = AttributedString(text)
        attr.font = .system(size: 10, weight: .medium)
        attr.foregroundColor = .white

        let resolvedText = context.resolve(Text(attr))
        let ringWidth = outerR - innerR
        let textSize = resolvedText.measure(in: CGSize(width: ringWidth, height: ringWidth))

        // Skip if the text is wider than 95% of the arc chord at mid-radius.
        let chord = 2 * midRadius * sin((endAngle - startAngle) / 2)
        guard textSize.width <= chord * 0.95 else { return }

        // Rotate so text runs tangentially (perpendicular to the radius).
        // On the bottom half the naive rotation is upside-down, so flip by π.
        var rotation = midAngle + .pi / 2
        // Normalise to [0, 2π] for the flip check.
        let normAngle = midAngle.truncatingRemainder(dividingBy: 2 * .pi) + (midAngle < 0 ? 2 * .pi : 0)
        if normAngle > .pi / 2, normAngle < 3 * .pi / 2 {
            rotation += .pi
        }

        context.drawLayer { layer in
            layer.translateBy(x: x, y: y)
            layer.rotate(by: Angle(radians: rotation))
            layer.draw(resolvedText, at: .zero, anchor: .center)
        }
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
