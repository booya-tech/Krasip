// CorrectionRow.swift
// Krasip
// One saved correction (before → after) and the glossary rules it could become.

import SwiftUI
import KrasipCore

struct CorrectionRow: View {
    @Environment(AppController.self) private var app
    let correction: Correction
    let onMakeRule: (Suggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(correction.createdAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if correction.acceptedSuggestion {
                    Label(AppString.Learning.becameRule, systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Text(correction.beforeText)
                .strikethrough(color: .secondary)
                .foregroundStyle(.secondary)
            Text(correction.afterText)
            ForEach(suggestions) { suggestion in
                SuggestionLine(suggestion: suggestion) {
                    onMakeRule(suggestion)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var suggestions: [Suggestion] {
        let glossary = app.glossary.glossary
        return glossary.learnAll(before: correction.beforeText, after: correction.afterText)
            .filter { !glossary.alreadyKnows($0) }
    }
}
