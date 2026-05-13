import SwiftUI
import Charts

struct ReleaseTimelineChart: View {
    let entries: [ReleaseTimelineEntry]

    enum Mode: String, CaseIterable, Identifiable {
        case base = "Base"
        case extended = "Extended"
        var id: String { rawValue }
        var origin: String { self == .base ? "release" : "xrelease" }
    }

    @State private var mode: Mode = .base

    enum Series: String, CaseIterable, Identifiable, Sendable {
        case species = "Species"
        case genera = "Genera"
        case families = "Families"
        case allNames = "All names"
        var id: String { rawValue }
    }

    /// Pre-computed flattened data points: (entry, series, value).
    private struct Point: Identifiable {
        let entry: ReleaseTimelineEntry
        let series: Series
        let value: Int
        var id: String { "\(entry.id)-\(series.rawValue)" }
    }

    private var filteredEntries: [ReleaseTimelineEntry] {
        entries.filter { $0.origin == mode.origin }
    }

    private var points: [Point] {
        filteredEntries.flatMap { entry in
            [
                Point(entry: entry, series: .species,  value: entry.species),
                Point(entry: entry, series: .genera,   value: entry.genera),
                Point(entry: entry, series: .families, value: entry.families),
                Point(entry: entry, series: .allNames, value: entry.nameCount),
            ]
        }
        // Log y-scale asserts on non-positive values; drop them rather than crash.
        .filter { $0.value > 0 }
    }

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Release timeline").font(.headline)
                    Spacer()
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                if filteredEntries.isEmpty {
                    Text("No \(mode.rawValue.lowercased()) releases available.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(points) { p in
                            if let date = p.entry.issuedDate {
                                LineMark(
                                    x: .value("Issued", date),
                                    y: .value("Count", p.value)
                                )
                                .foregroundStyle(by: .value("Series", p.series.rawValue))
                                .symbol(by: .value("Series", p.series.rawValue))
                            }
                        }
                    }
                    .chartYScale(type: .log)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartLegend(position: .bottom)
                    .frame(height: 240)
                }
            }
        }
    }
}
