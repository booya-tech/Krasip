// PreferredSpellingSheet.swift
// Krasip
// "Add preferred spelling" from a transcript span or a correction: alias → preferred output, as a locked rule.

import SwiftUI
import KrasipCore

struct PreferredSpellingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppController.self) private var app

    let draft: SpellingDraft
    let record: DictationRecord
    let onSaved: () -> Void

    @State private var alias: String
    @State private var preferredOutput: String
    @State private var mode: GlossaryEntry.Mode = .locked
    @State private var fixThisDictation = true
    @State private var error: String?

    init(draft: SpellingDraft, record: DictationRecord, onSaved: @escaping () -> Void) {
        self.draft = draft
        self.record = record
        self.onSaved = onSaved
        _alias = State(initialValue: draft.alias)
        _preferredOutput = State(initialValue: draft.preferredOutput)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppString.Glossary.addPreferredTitle)
                .font(.title2.weight(.semibold))
            Text(AppString.Glossary.addPreferredIntro)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Form {
                TextField(AppString.Glossary.aliasField, text: $alias)
                TextField(AppString.Glossary.preferredField, text: $preferredOutput, prompt: Text(verbatim: "side-project"))
                Picker(AppString.Glossary.modeField, selection: $mode) {
                    ForEach(GlossaryEntry.Mode.allCases) { mode in
                        Text(AppString.Glossary.modeName(mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(AppString.Glossary.fixThisDictation, isOn: $fixThisDictation)
                    .disabled(mode != .locked)
            }
            .formStyle(.grouped)

            if let preview {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppString.Glossary.preview)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(preview)
                }
            }
            if let error {
                Text(error)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button(AppString.Common.cancel, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(AppString.Glossary.saveRule, action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(alias.trimmingCharacters(in: .whitespaces).isEmpty || preferredOutput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    /// This dictation's raw transcript run through the glossary with the new rule added.
    private var preview: String? {
        guard !alias.isEmpty, !preferredOutput.isEmpty else { return nil }
        var entries = app.glossary.entries
        entries.append(GlossaryEntry(aliases: [alias], preferredOutput: preferredOutput, mode: .locked))
        return TextPolicy().finalize(record.rawText, glossary: Glossary(entries), style: app.style(forApp: record.destinationBundleID)).text
    }

    private func save() {
        guard app.glossary.add(aliases: [alias], preferredOutput: preferredOutput, mode: mode) else {
            error = app.glossary.lastError
            return
        }
        if let correctionID = draft.correctionID {
            app.history.markAccepted(correctionID: correctionID)
        }
        if fixThisDictation, mode == .locked {
            let fixed = TextPolicy().finalize(record.rawText, glossary: app.glossary.glossary, style: app.style(forApp: record.destinationBundleID)).text
            if fixed != record.finalText {
                app.history.applyCorrection(id: record.id, text: fixed)
            }
        }
        onSaved()
        dismiss()
    }
}
