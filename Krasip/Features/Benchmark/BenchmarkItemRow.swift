// BenchmarkItemRow.swift
// Krasip
// One benchmark sentence in the list: id, script, recorded state, and a pass mark per engine.

import SwiftUI
import KrasipCore

struct BenchmarkItemRow: View {
    let model: BenchmarkModel
    let item: BenchmarkItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: recordingSymbol)
                .foregroundStyle(recordingTint)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.id)
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(.secondary)
                    if model.isCustom(item) {
                        Text(AppString.Benchmark.mine)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 5)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                    Spacer()
                    ForEach(SpeechEngine.available) { engine in
                        if let score = model.score(for: item, engine: engine) {
                            Image(systemName: score.missingTerms.isEmpty && score.characterErrorRate < 0.15 ? "checkmark" : "xmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(score.missingTerms.isEmpty ? .green : .orange)
                                .help(AppString.Languages.engineName(engine))
                        }
                    }
                }
                Text(item.script)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var recordingSymbol: String {
        if model.recordingItemID == item.id { return "record.circle.fill" }
        if model.syntheticIDs.contains(item.id) { return "speaker.wave.2.circle" }
        return model.recordedIDs.contains(item.id) ? "waveform.circle.fill" : "circle"
    }

    private var recordingTint: Color {
        if model.recordingItemID == item.id { return .red }
        return model.recordedIDs.contains(item.id) ? .accentColor : .secondary
    }
}
