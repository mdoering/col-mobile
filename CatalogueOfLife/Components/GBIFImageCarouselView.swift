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
                FullScreenImageView(item: item) {
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

private struct FullScreenImageView: View {
    let item: GBIFMediaItem
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                AsyncImage(url: item.imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFit()
                    case .failure: Image(systemName: "photo").foregroundStyle(.white)
                    case .empty: ProgressView().tint(.white)
                    @unknown default: Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                attribution
                    .padding()
                    .background(.black.opacity(0.6))
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
            }
            .accessibilityLabel("Close")
        }
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
