// BenchmarkSummaryView.swift
// Krasip
// Per-engine comparison: term preservation, unwanted transliteration, character error rate, exact match, latency.

import SwiftUI
import KrasipCore

struct BenchmarkSummaryView: View {
    let model: BenchmarkModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppString.Benchmark.summaryTitle)
                .font(.title2.weight(.semibold))
            Text(AppString.Benchmark.summaryIntro)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                GridRow {
                    Text(AppString.Benchmark.engineColumn)
                    Text(AppString.Benchmark.termsColumn)
                    Text(AppString.Benchmark.transliterationColumn)
                    Text(AppString.Benchmark.cerColumn)
                    Text(AppString.Benchmark.exactColumn)
                    Text(AppString.Benchmark.latencyColumn)
                    Text(AppString.Benchmark.countColumn)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Divider()
                ForEach(SpeechEngine.available) { engine in
                    GridRow {
                        Text(AppString.Languages.engineName(engine))
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .fixedSize()
                        if let summary = model.summary(for: engine) {
                            Text(percent(summary.termPreservationRate))
                            Text(percent(summary.unwantedTransliterationRate))
                            Text(percent(summary.meanCharacterErrorRate))
                            Text(percent(summary.exactMatchRate))
                            Text(summary.medianLatency.map { String(format: "%.1fs", $0) } ?? "–")
                            Text("\(summary.count)")
                        } else {
                            Text(AppString.Benchmark.notRun)
                                .foregroundStyle(.tertiary)
                                .gridCellColumns(6)
                        }
                    }
                    .monospacedDigit()
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))

            if !model.syntheticIDs.isEmpty {
                Label(AppString.Benchmark.syntheticWarning(model.syntheticIDs.count), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func percent(_ value: Double?) -> String {
        value.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–"
    }
}
