// QualityStatsView.swift
// Krasip
// The quality plan's everyday metrics: insertion success, correction rate, and latency.

import SwiftUI
import KrasipCore

struct QualityStatsView: View {
    let stats: QualityStats

    var body: some View {
        HStack(spacing: 8) {
            tile(AppString.Stats.dictations, value: "\(stats.dictationCount)", help: AppString.Stats.dictationsHelp)
            tile(AppString.Stats.insertion, value: percent(stats.insertionSuccessRate), help: AppString.Stats.insertionHelp)
            tile(AppString.Stats.corrections, value: percent(stats.correctionRate), help: AppString.Stats.correctionsHelp)
            tile(AppString.Stats.latency, value: seconds(stats.medianLatency), help: AppString.Stats.latencyHelp)
        }
    }

    private func tile(_ title: String, value: String, help: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .help(help)
    }

    private func percent(_ value: Double?) -> String {
        value.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–"
    }

    private func seconds(_ value: TimeInterval?) -> String {
        value.map { String(format: "%.1fs", $0) } ?? "–"
    }
}
