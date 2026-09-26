// GlossaryEntryEditor.swift
// Krasip
// Sheet for adding or editing one preferred spelling, its aliases, and its mode, with a live preview.

import SwiftUI
import KrasipCore

struct GlossaryEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppController.self) private var app

    private let original: GlossaryEntry?
    private let onSave: (GlossaryEntry) -> Bool
    @State private var preferredOutput: String
    @State private var aliasesText: String
    @State private var mode: GlossaryEntry.Mode
    @State private var error: String?

    init(entry: GlossaryEntry?, prefilledAlias: String? = nil, onSave: @escaping (GlossaryEntry) -> Bool) {
        original = entry
        self.onSave = onSave
        _preferredOutput = State(initialValue: entry?.preferredOutput ?? "")
        let aliases = entry?.aliases ?? prefilledAlias.map { [$0] } ?? []
        _aliasesText = State(initialValue: aliases.joined(separator: "\n"))
        _mode = State(initialValue: entry?.mode ?? .locked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(original == nil ? AppString.Glossary.addTitle : AppString.Glossary.editTitle)
                .font(.title2.weight(.semibold))

            Form {
                TextField(AppString.Glossary.preferredField, text: $preferredOutput, prompt: Text(verbatim: "side-project"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppString.Glossary.aliasesField)
                    TextEditor(text: $aliasesText)
                        .font(.body)
                        .frame(height: 90)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    Text(AppString.Glossary.aliasesHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker(AppString.Glossary.modeField, selection: $mode) {
                    ForEach(GlossaryEntry.Mode.allCases) { mode in
                        Text(AppString.Glossary.modeName(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(AppString.Glossary.modeHelp(mode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)

            if !draft.riskyAliases.isEmpty {
                Label(AppString.Glossary.riskyAliases(draft.riskyAliases), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let example = preview {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppString.Glossary.preview)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(example)
                }
            }

            if let error {
                Text(error)
                    .foregroundStyle(.orange)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button(AppString.Common.cancel, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(AppString.Common.save) {
                    if onSave(draft) {
                        dismiss()
                    } else {
                        error = app.glossary.lastError
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(preferredOutput.trimmingCharacters(in: .whitespaces).isEmpty || aliases.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private var aliases: [String] {
        aliasesText
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var draft: GlossaryEntry {
        GlossaryEntry(
            id: original?.id ?? UUID(),
            aliases: aliases,
            preferredOutput: preferredOutput,
            mode: mode,
            createdAt: original?.createdAt ?? .now
        )
    }

    /// Shows the first alias inside a sample sentence and what the policy makes of it.
    private var preview: String? {
        guard let alias = aliases.first, !preferredOutput.isEmpty else { return nil }
        let sample = "วันนี้ต้องทำ\(alias)ให้เสร็จ"
        var entry = draft
        entry.mode = .locked
        let result = TextPolicy().finalize(sample, glossary: Glossary([entry]), style: app.settings.textStyle)
        return "\(sample)  →  \(result.text)"
    }
}
