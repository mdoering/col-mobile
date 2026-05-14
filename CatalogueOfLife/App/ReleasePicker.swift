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
        // Without this the menu's button label tries to wrap "Latest Extended"
        // onto two lines under the parent HStack's tight layout. Pin to the
        // intrinsic width so the picker keeps the value on one line.
        .fixedSize(horizontal: true, vertical: false)
    }
}
