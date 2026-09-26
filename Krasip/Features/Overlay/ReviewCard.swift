// ReviewCard.swift
// Krasip
// Overlay card that holds the text for review: raw transcript when confidence is low, suggestions, edits, undo.

import SwiftUI
import KrasipCore

struct ReviewCard: View {
    @Environment(AppController.self) private var app
    @FocusState private var editorFocused: Bool
    let review: FlowPhase.Review

    private var isEditing: Bool { app.overlay.isEditing }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if review.reasons.contains(.lowConfidence) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppString.Overlay.heard)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(review.transcript.rawText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if isEditing {
                TextEditor(text: editedText)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .padding(6)
                    .frame(minHeight: 70, maxHeight: 150)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .onAppear { editorFocused = true }
            } else {
                Text(review.text)
                    .font(.system(size: 15))
                    .lineLimit(8)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !isEditing {
                ForEach(review.finalText.suggestions) { suggestion in
                    SuggestionRow(suggestion: suggestion) {
                        app.flow.accept(suggestion)
                    }
                }
                ChangeList(changes: review.finalText.visibleChanges) { change in
                    app.flow.undo(change)
                }
            }

            buttons
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.viewfinder")
                .foregroundStyle(.tint)
            Text(AppString.Overlay.reviewTitle)
                .font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 8)
            ForEach(reasonLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            Button(AppString.Overlay.cancel) { app.flow.cancel() }
                .help(AppString.Overlay.cancelHelp)
            Button(AppString.Overlay.copy) { app.flow.copyReviewText() }
            if isEditing {
                Button(AppString.Overlay.revertEdits) { app.flow.updateReviewText(nil) }
                    .disabled(review.editedText == nil)
            } else {
                Button(AppString.Overlay.edit) { app.overlay.beginEditing() }
            }
            Spacer()
            Button {
                app.flow.confirm()
            } label: {
                HStack(spacing: 4) {
                    Text(AppString.Overlay.insert)
                    Text(isEditing ? "⌘↩" : "↩")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: isEditing ? .command : [])
        }
        .controlSize(.small)
    }

    private var editedText: Binding<String> {
        Binding {
            review.text
        } set: { newValue in
            app.flow.updateReviewText(newValue)
        }
    }

    private var reasonLabels: [String] {
        var labels: [String] = []
        if review.reasons.contains(.lowConfidence) {
            labels.append(AppString.Overlay.lowConfidence(review.transcript.confidence ?? 0))
        }
        if review.reasons.contains(.suggestions) {
            labels.append(AppString.Overlay.suggestionBadge)
        }
        if review.reasons.contains(.reviewMode) {
            labels.append(AppString.Overlay.reviewModeBadge)
        }
        return labels
    }
}
