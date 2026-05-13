import SwiftUI

struct RemarksView: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).font(.callout).textSelection(.enabled)
        }
    }
}
