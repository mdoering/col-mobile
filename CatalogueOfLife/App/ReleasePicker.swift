import SwiftUI

struct ReleasePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Menu {
            Picker("Release", selection: $state.selectedDatasetKey) {
                ForEach(state.availableReleases) { ref in
                    Text(label(for: ref)).tag(ref.key)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(state.selectedDataset.map(label(for:)) ?? "Loading…")
                    .font(.subheadline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
        }
        .accessibilityLabel("Selected release")
    }

    private func label(for ref: DatasetRef) -> String {
        if let alias = ref.alias { return alias }
        if let issued = ref.issued?.prefix(4) { return "Annual \(issued)" }
        return ref.title
    }
}
