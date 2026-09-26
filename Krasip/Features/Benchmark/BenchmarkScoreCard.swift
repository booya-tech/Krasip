// BenchmarkScoreCard.swift
// Krasip
// One engine's result for one sentence: raw and final text, missing terms, and error rate.

import SwiftUI
import KrasipCore

struct BenchmarkScoreCard: View {
    let engine: SpeechEngine
    let score: BenchmarkScore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(AppString.Languages.engineName(engine))
                    .font(.headline)
                Spacer()
                Text(AppString.Benchmark.cer(score.characterErrorRate))
                    .monospacedDigit()
                if let latency = score.latency {
                    Text(String(format: "%.1fs", latency))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent(AppString.Benchmark.raw) {
                Text(score.rawText.isEmpty ? "–" : score.rawText)
                    .textSelection(.enabled)
            }
            LabeledContent(AppString.Benchmark.final) {
                Text(score.finalText.isEmpty ? "–" : score.finalText)
                    .fontWeight(.medium)
                    .textSelection(.enabled)
            }
            if !score.missingTerms.isEmpty {
                Label(AppString.Benchmark.missing(score.missingTerms), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
            }
            if !score.transliteratedTerms.isEmpty {
                Label(AppString.Benchmark.transliterated(score.transliteratedTerms), systemImage: "character.bubble")
                    .foregroundStyle(.orange)
            }
            if score.exactMatch {
                Label(AppString.Benchmark.exactMatch, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .font(.callout)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
