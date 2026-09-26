// SuggestionLine.swift
// Krasip
// A rule a correction could become: "ไซต์โปรเจกต์ → side-project  [Make Rule…]".

import SwiftUI
import KrasipCore

struct SuggestionLine: View {
    let suggestion: Suggestion
    let onMakeRule: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb")
                .foregroundStyle(.yellow)
            Text(suggestion.alias)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(suggestion.preferredOutput)
                .fontWeight(.medium)
            Spacer(minLength: 4)
            Button(AppString.Learning.makeRule, action: onMakeRule)
                .controlSize(.small)
        }
        .font(.callout)
        .lineLimit(1)
    }
}
