import SwiftUI

/// Fullscreen sunburst with pinch-to-zoom + pan. The sunburst is rendered larger
/// than the screen so more labels fit naturally as the user zooms in. Tap an arc
/// to open its detail (same flow as the inline sunburst's popover → "Tap to open").
struct SunburstFullScreenView: View {
    let root: SunburstNode
    var maxDepth: Int = 2
    var popoverKind: SunburstView.PopoverKind = .taxon
    var onSelect: (SunburstNode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 6

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) * zoom
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    SunburstView(
                        root: root,
                        maxDepth: maxDepth,
                        popoverKind: popoverKind,
                        alwaysShowLabels: true
                    ) { node in
                        onSelect(node)
                        dismiss()
                    }
                    .frame(width: side, height: side)
                    .offset(pan)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(combinedGesture)
            }
            .navigationTitle(root.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { resetView() }
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                    }
                    .accessibilityLabel("Reset zoom")
                }
            }
        }
    }

    private var combinedGesture: some Gesture {
        let magnify = MagnifyGesture()
            .onChanged { value in
                zoom = max(minZoom, min(lastZoom * value.magnification, maxZoom))
            }
            .onEnded { _ in lastZoom = zoom }

        let drag = DragGesture()
            .onChanged { value in
                pan = CGSize(width: lastPan.width + value.translation.width,
                             height: lastPan.height + value.translation.height)
            }
            .onEnded { _ in lastPan = pan }

        return SimultaneousGesture(magnify, drag)
    }

    private func resetView() {
        zoom = 1
        lastZoom = 1
        pan = .zero
        lastPan = .zero
    }
}
