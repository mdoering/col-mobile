import SwiftUI

struct PublishedInView: View {
    let citation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Published in").font(.headline)
            HTMLText(html: citation)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}
