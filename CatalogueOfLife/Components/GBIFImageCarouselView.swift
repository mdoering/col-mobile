import SwiftUI

struct GBIFImageCarouselView: View {
    let items: [GBIFMediaItem]
    @State private var selectedFullScreen: GBIFMediaItem?

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            TabView {
                ForEach(items) { item in
                    Button {
                        selectedFullScreen = item
                    } label: {
                        AsyncImage(url: item.imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill().clipped()
                            case .failure:
                                placeholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                placeholder
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 240)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .fullScreenCover(item: $selectedFullScreen) { item in
                let startIdx = items.firstIndex(where: { $0.id == item.id }) ?? 0
                FullScreenImagePager(items: items, initialIndex: startIdx) {
                    selectedFullScreen = nil
                }
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.15))
            .overlay(Image(systemName: "photo").foregroundStyle(.secondary).font(.title))
    }
}

private struct FullScreenImagePager: View {
    let items: [GBIFMediaItem]
    let initialIndex: Int
    let onDismiss: () -> Void
    @State private var current: Int

    init(items: [GBIFMediaItem], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.items = items
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self._current = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $current) {
                ForEach(items.indices, id: \.self) { idx in
                    FullScreenImagePage(item: items[idx], isActive: idx == current)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .padding()
            }
            .accessibilityLabel("Close")
        }
    }
}

/// One page in the fullscreen pager: image + zoom/pan + attribution overlay.
/// When `isActive` flips false (user swiped away) we reset zoom so returning
/// to the page starts unzoomed.
private struct FullScreenImagePage: View {
    let item: GBIFMediaItem
    let isActive: Bool

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            AsyncImage(url: item.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                        .scaleEffect(zoom)
                        .offset(pan)
                        .gesture(zoomGesture)
                        // High-priority pan when zoomed in so the TabView's page
                        // swipe doesn't fight our drag. When zoom == 1 we don't
                        // attach the gesture, leaving TabView free to swipe.
                        .modifier(PanModifier(active: zoom > 1, gesture: panGesture))
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(duration: 0.25)) {
                                if zoom > 1 { resetZoom() } else { zoom = 2.5; lastZoom = 2.5 }
                            }
                        }
                case .failure: Image(systemName: "photo").foregroundStyle(.white)
                case .empty: ProgressView().tint(.white)
                @unknown default: Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            attribution
                .padding()
                .background(.black.opacity(0.6))
        }
        .onChange(of: isActive) { _, active in
            if !active { resetZoom() }
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = max(minZoom, min(lastZoom * value.magnification, maxZoom))
            }
            .onEnded { _ in
                if zoom <= 1 { resetZoom() } else { lastZoom = zoom }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                pan = CGSize(
                    width: lastPan.width + value.translation.width,
                    height: lastPan.height + value.translation.height
                )
            }
            .onEnded { _ in lastPan = pan }
    }

    private func resetZoom() {
        zoom = 1
        lastZoom = 1
        pan = .zero
        lastPan = .zero
    }

    private var attribution: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let creator = item.creator {
                Text("© \(creator)").font(.caption).foregroundStyle(.white)
            }
            if let rights = item.rightsHolder, rights != item.creator {
                Text(rights).font(.caption2).foregroundStyle(.white.opacity(0.85))
            }
            if let publisher = item.publisher {
                Text(publisher).font(.caption2).foregroundStyle(.white.opacity(0.75))
            }
            HStack(spacing: 8) {
                if let license = item.license, let url = URL(string: license) {
                    Link(licenseLabel(license), destination: url).font(.caption2)
                } else if let license = item.license {
                    Text(license).font(.caption2).foregroundStyle(.white.opacity(0.85))
                }
                if let source = item.sourceURL {
                    Link("Source", destination: source).font(.caption2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Heuristic short label: "CC BY-NC 4.0" from a CC URL, otherwise the URL.
    private func licenseLabel(_ url: String) -> String {
        let lower = url.lowercased()
        if lower.contains("/by-nc-sa") { return "CC BY-NC-SA" }
        if lower.contains("/by-nc-nd") { return "CC BY-NC-ND" }
        if lower.contains("/by-nc")    { return "CC BY-NC" }
        if lower.contains("/by-sa")    { return "CC BY-SA" }
        if lower.contains("/by")       { return "CC BY" }
        if lower.contains("publicdomain") { return "Public Domain" }
        return "License"
    }
}

/// Attaches a drag gesture as a high-priority gesture only when `active` is true,
/// so the TabView page swipe still works in the unzoomed state.
private struct PanModifier<G: Gesture>: ViewModifier {
    let active: Bool
    let gesture: G
    func body(content: Content) -> some View {
        if active {
            content.highPriorityGesture(gesture)
        } else {
            content
        }
    }
}
