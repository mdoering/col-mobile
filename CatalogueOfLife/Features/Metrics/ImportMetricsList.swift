import SwiftUI

struct ImportMetricsList: View {
    let metrics: ImportMetrics
    var includeSummary: Bool = true
    var includeSections: Bool = true

    @State private var expandedSections: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if includeSummary && !metrics.summary.isEmpty {
                section(title: "Summary", rows: metrics.summary)
            }
            if includeSections {
                ForEach(metrics.sections, id: \.title) { sec in
                    Divider()
                    section(title: sec.title, rows: sec.rows)
                }
            }
        }
    }

    private func section(title: String, rows: [MetricRow]) -> some View {
        let isRankSection = rows.contains { $0.rank != nil }
        let expanded = expandedSections.contains(title)
        let visibleRows: [MetricRow] = isRankSection && !expanded
            ? rows.filter { $0.rank?.isMainLinnean == true }
            : rows
        let hiddenCount = rows.count - visibleRows.count

        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(visibleRows) { row in
                HStack {
                    Text(row.label).font(.callout)
                    Spacer()
                    Text(row.value, format: .number).font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if isRankSection && hiddenCount > 0 {
                Button {
                    if expanded {
                        expandedSections.remove(title)
                    } else {
                        expandedSections.insert(title)
                    }
                } label: {
                    Text(expanded ? "Show fewer" : "Show all \(rows.count) ranks")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
            }
        }
    }
}
