import SwiftUI

struct ImportMetricsList: View {
    let metrics: ImportMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !metrics.summary.isEmpty {
                section(title: "Summary", rows: metrics.summary)
            }
            ForEach(metrics.sections, id: \.title) { section in
                Divider()
                self.section(title: section.title, rows: section.rows)
            }
        }
    }

    private func section(title: String, rows: [MetricRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(rows) { row in
                HStack {
                    Text(row.label).font(.callout)
                    Spacer()
                    Text(row.value, format: .number).font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
