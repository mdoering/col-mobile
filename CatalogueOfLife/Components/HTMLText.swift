import SwiftUI
import Foundation

extension AttributedString {
    /// Convert HTML content (e.g. CSL citation) into AttributedString. Returns nil on parse failure.
    ///
    /// Internally uses `NSAttributedString`'s HTML parser, which spins the main runloop —
    /// **never call this from inside a SwiftUI `body`** (it causes AttributeGraph cycles).
    /// `HTMLText` defers the call to `.task` so the parse runs after the current view update.
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

/// Renders an HTML string as SwiftUI Text. Parses asynchronously off the current view-update
/// cycle (via `.task`) to avoid the AttributeGraph cycle that `NSAttributedString`'s HTML
/// parser triggers when invoked synchronously inside `body`. Shows a plain-text fallback
/// (HTML tags stripped) while parsing or if parsing fails.
struct HTMLText: View {
    let html: String
    @State private var parsed: AttributedString?

    var body: some View {
        Group {
            if let parsed {
                Text(parsed)
            } else {
                Text(stripped(html))
            }
        }
        .task(id: html) {
            // Yield so the current SwiftUI update pass finishes before the HTML parser
            // spins the runloop. Without this, the parser is invoked re-entrantly during
            // body evaluation and AttributeGraph throws "cyclic graph".
            await Task.yield()
            parsed = AttributedString(html: html)
        }
    }

    private func stripped(_ s: String) -> String {
        s
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&aacute;", with: "á")
            .replacingOccurrences(of: "&Aacute;", with: "Á")
            .replacingOccurrences(of: "&eacute;", with: "é")
            .replacingOccurrences(of: "&Eacute;", with: "É")
            .replacingOccurrences(of: "&iacute;", with: "í")
            .replacingOccurrences(of: "&Iacute;", with: "Í")
            .replacingOccurrences(of: "&oacute;", with: "ó")
            .replacingOccurrences(of: "&Oacute;", with: "Ó")
            .replacingOccurrences(of: "&uacute;", with: "ú")
            .replacingOccurrences(of: "&Uacute;", with: "Ú")
            .replacingOccurrences(of: "&ouml;", with: "ö")
            .replacingOccurrences(of: "&Ouml;", with: "Ö")
            .replacingOccurrences(of: "&auml;", with: "ä")
            .replacingOccurrences(of: "&Auml;", with: "Ä")
            .replacingOccurrences(of: "&uuml;", with: "ü")
            .replacingOccurrences(of: "&Uuml;", with: "Ü")
            .replacingOccurrences(of: "&ntilde;", with: "ñ")
            .replacingOccurrences(of: "&Ntilde;", with: "Ñ")
    }
}
