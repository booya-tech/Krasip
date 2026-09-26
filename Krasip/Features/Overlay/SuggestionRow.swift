// SuggestionRow.swift
// Krasip
// A glossary suggestion waiting for the user: "ไซต์โปรเจกต์ → side-project  [Use]".

import SwiftUI
import KrasipCore

struct SuggestionRow: View {
    let suggestion: PendingSuggestion
    let onUse: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb")
                .foregroundStyle(.yellow)
            Text(suggestion.matchedText)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(suggestion.preferredOutput)
                .fontWeight(.medium)
            if suggestion.isSoundAlike {
                Text("· \(AppString.Overlay.soundsLike)")
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Button(AppString.Overlay.useSuggestion, action: onUse)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .font(.callout)
        .lineLimit(1)
    }
}
