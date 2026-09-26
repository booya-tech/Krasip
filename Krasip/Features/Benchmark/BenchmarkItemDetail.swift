// BenchmarkItemDetail.swift
// Krasip
// The selected benchmark sentence: what to say, record/play controls, and each engine's result.

import SwiftUI
import KrasipCore

struct BenchmarkItemDetail: View {
    let model: BenchmarkModel
    let item: BenchmarkItem

    private var isRecording: Bool { model.recordingItemID == item.id }
    private var isRecorded: Bool { model.recordedIDs.contains(item.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.id)
                    .font(.headline.monospaced())
                Text(AppString.Benchmark.categoryName(item.category))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Text(AppString.Benchmark.say)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.script)
                .font(.system(size: 22, weight: .medium))
                .textSelection(.enabled)
            if let note = item.note {
                Label(note, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(AppString.Benchmark.expected(item.expected))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    model.toggleRecording(item)
                } label: {
                    Label(isRecording ? AppString.Benchmark.stopRecording : AppString.Benchmark.record,
                          systemImage: isRecording ? "stop.fill" : "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : .accentColor)
                .keyboardShortcut("r", modifiers: .command)
                Button(AppString.Benchmark.play, systemImage: "play.fill") { model.play(item) }
                    .disabled(!isRecorded || isRecording)
                Button(AppString.Benchmark.deleteRecording, systemImage: "trash") { model.deleteRecording(item) }
                    .disabled(!isRecorded || isRecording)
            }

            ForEach(SpeechEngine.available) { engine in
                if let score = model.score(for: item, engine: engine) {
                    BenchmarkScoreCard(engine: engine, score: score)
                }
            }
        }
    }
}
