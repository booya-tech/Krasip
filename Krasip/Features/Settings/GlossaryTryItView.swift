// GlossaryTryItView.swift
// Krasip
// Type what a recognizer might write and see the final text and every change, using your real glossary.

import SwiftUI
import KrasipCore

struct GlossaryTryItView: View {
    @Environment(AppController.self) private var app
    @State private var raw = "วันนี้จะต้องกลับบ้านไปทำไซต์โปรเจกต์ตอน ten PM"

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                TextField(AppString.Glossary.tryItPlaceholder, text: $raw)
                    .textFieldStyle(.roundedBorder)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.secondary)
                    Text(result.text.isEmpty ? " " : result.text)
                        .font(.body.weight(.medium))
                        .textSelection(.enabled)
                }
                ChangeList(changes: result.visibleChanges)
                ForEach(result.suggestions) { suggestion in
                    Label(
                        suggestion.isSoundAlike
                            ? AppString.Glossary.wouldAskSoundAlike(suggestion.matchedText, suggestion.preferredOutput)
                            : AppString.Glossary.wouldAsk(suggestion.matchedText, suggestion.preferredOutput),
                        systemImage: "lightbulb"
                    )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(4)
        } label: {
            Text(AppString.Glossary.tryIt)
        }
    }

    private var result: FinalText {
        TextPolicy().finalize(raw, glossary: app.glossary.glossary, style: app.settings.textStyle)
    }
}
