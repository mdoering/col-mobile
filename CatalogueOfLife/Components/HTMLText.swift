import SwiftUI
import Foundation

extension AttributedString {
    /// Convert HTML content (e.g. CSL citation) into AttributedString. Returns nil on parse failure.
    /// Uses NSAttributedString's HTML parser, which must be called on the main actor.
    @MainActor
    init?(html: String) {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        self.init(ns)
    }
}

/// Renders an HTML string as a SwiftUI Text via AttributedString. Falls back to plain text
/// (with HTML stripped via regex) if parsing fails.
struct HTMLText: View {
    let html: String

    var body: some View {
        if let attr = AttributedString(html: html) {
            Text(attr)
        } else {
            Text(stripped)
        }
    }

    private var stripped: String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
