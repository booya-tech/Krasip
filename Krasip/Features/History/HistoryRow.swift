// HistoryRow.swift
// Krasip
// One dictation in the history list: time, app, text preview, and status badges.

import SwiftUI
import KrasipCore

struct HistoryRow: View {
    let record: DictationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(record.startedAt, format: .dateTime.day().month().hour().minute())
                if let app = record.destinationAppName {
                    Text("· \(app)")
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                ForEach(badges, id: \.symbol) { badge in
                    Image(systemName: badge.symbol)
                        .foregroundStyle(badge.color)
                        .help(badge.help)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(record.finalText)
                .lineLimit(2)
        }
        .padding(.vertical, 3)
    }

    private struct Badge {
        let symbol: String
        let color: Color
        let help: String
    }

    private var badges: [Badge] {
        var result: [Badge] = []
        switch record.insertion {
        case .copiedToClipboard(.userChoseCopy):
            result.append(Badge(symbol: "doc.on.doc", color: .secondary, help: AppString.History.badgeCopied))
        case .copiedToClipboard:
            result.append(Badge(symbol: "doc.on.clipboard", color: .orange, help: AppString.History.badgeFallback))
        case .cancelled:
            result.append(Badge(symbol: "xmark.circle", color: .secondary, help: AppString.History.badgeCancelled))
        default:
            break
        }
        if let confidence = record.confidence, confidence < 0.5 {
            result.append(Badge(symbol: "questionmark.circle", color: .yellow, help: AppString.History.badgeLowConfidence))
        }
        if record.wasCorrected {
            result.append(Badge(symbol: "pencil.circle", color: .accentColor, help: AppString.History.badgeCorrected))
        }
        if record.audioPath != nil {
            result.append(Badge(symbol: "waveform.circle", color: .secondary, help: AppString.History.badgeAudio))
        }
        return result
    }
}
