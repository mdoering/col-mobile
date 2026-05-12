import SwiftUI

struct PreferredLanguagePicker: View {
    @Environment(AppState.self) private var appState

    /// (storedCode, displayLabel). nil = "System default" (system fallback handled by AppState).
    private static let languages: [(String?, String)] = [
        (nil, "System default"),
        ("eng", "English"),
        ("spa", "Español"),
        ("fra", "Français"),
        ("deu", "Deutsch"),
        ("por", "Português"),
        ("ita", "Italiano"),
        ("nld", "Nederlands"),
        ("zho", "中文"),
        ("jpn", "日本語"),
        ("rus", "Русский"),
        ("ara", "العربية"),
    ]

    var body: some View {
        @Bindable var state = appState
        Picker("Common-name language", selection: $state.preferredVernacularLang) {
            ForEach(Self.languages, id: \.0) { code, label in
                Text(label).tag(code)
            }
        }
        .pickerStyle(.menu)
    }
}
