import SwiftUI

struct ReleasePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Picker("Release", selection: $state.selectedDatasetKey) {
            ForEach(state.availableReleases) { choice in
                Text(choice.displayName).tag(choice.dataset.key)
            }
        }
        .pickerStyle(.menu)
    }
}
