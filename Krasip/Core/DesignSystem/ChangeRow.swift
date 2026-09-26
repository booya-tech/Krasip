// ChangeRow.swift
// Krasip
// One explained text change, e.g. "side project → side-project · glossary", with an optional undo button.

import SwiftUI
import KrasipCore

struct ChangeRow: View {
    let change: TextChange
    var onUndo: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 14)
            Text(visible(change.before))
                .strikethrough(change.kind == .glossary || change.kind == .spokenTime, color: .secondary)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(visible(change.after))
                .fontWeight(.medium)
            Text("· \(AppString.Changes.label(for: change.kind))")
                .foregroundStyle(.tertiary)
            Spacer(minLength: 4)
            if let onUndo {
                Button(AppString.Changes.undo, action: onUndo)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .help(AppString.Changes.undoHelp)
            }
        }
        .font(.callout)
        .lineLimit(1)
        .truncationMode(.middle)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch change.kind {
        case .glossary: "text.book.closed"
        case .spokenTime: "clock"
        case .spacing: "arrow.left.and.right"
        case .punctuation: "textformat"
        case .normalization: "wand.and.stars"
        }
    }

    /// Makes spaces visible in spacing changes, where the space is the whole point.
    private func visible(_ text: String) -> String {
        if text.isEmpty {
            return AppString.Changes.removed
        }
        return change.kind == .spacing ? text.replacingOccurrences(of: " ", with: "␣") : text
    }
}
