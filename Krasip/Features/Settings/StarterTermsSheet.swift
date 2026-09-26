// StarterTermsSheet.swift
// Krasip
// Optional pack of common English work terms and the Thai spellings recognizers produce for them.

import SwiftUI
import KrasipCore

struct StarterTermsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (GlossaryEntry.Mode) -> Void
    @State private var mode: GlossaryEntry.Mode = .suggest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppString.Glossary.starterTitle)
                .font(.title2.weight(.semibold))
            Text(AppString.Glossary.starterIntro)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(GlossaryModel.starterTerms, id: \.output) { term in
                HStack {
                    Text(term.output)
                        .fontWeight(.medium)
                        .frame(width: 120, alignment: .leading)
                    Text(term.aliases.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 260)

            Picker(AppString.Glossary.modeField, selection: $mode) {
                Text(AppString.Glossary.modeName(.suggest)).tag(GlossaryEntry.Mode.suggest)
                Text(AppString.Glossary.modeName(.locked)).tag(GlossaryEntry.Mode.locked)
            }
            .pickerStyle(.segmented)
            Text(AppString.Glossary.modeHelp(mode))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(AppString.Common.cancel, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(AppString.Glossary.addStarterTerms) {
                    onAdd(mode)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
