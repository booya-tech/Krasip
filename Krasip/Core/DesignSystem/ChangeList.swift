// ChangeList.swift
// Krasip
// The changes a dictation went through, with spacing fixes folded into one line to keep it short.

import SwiftUI
import KrasipCore

struct ChangeList: View {
    let changes: [TextChange]
    var limit: Int?
    var onUndo: ((TextChange) -> Void)?

    var body: some View {
        let main = changes.filter { $0.kind != .spacing }
        let spacing = changes.filter { $0.kind == .spacing }
        let shown = limit.map { Array(main.prefix($0)) } ?? main

        ForEach(shown) { change in
            ChangeRow(change: change, onUndo: onUndo.map { undo in { undo(change) } })
        }
        if let first = spacing.first {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(.tint)
                    .frame(width: 14)
                Text(AppString.Changes.spacingSummary(spacing.count))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let onUndo {
                    Button(AppString.Changes.undo) { onUndo(first) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help(AppString.Changes.undoSpacingHelp)
                }
            }
            .font(.callout)
            .lineLimit(1)
        }
        if main.count > shown.count {
            Text(AppString.Overlay.moreChanges(main.count - shown.count))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
