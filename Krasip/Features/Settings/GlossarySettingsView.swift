// GlossarySettingsView.swift
// Krasip
// Glossary tab: your preferred spellings, their aliases and modes, import/export, and a live "try it" box.

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import KrasipCore

struct GlossarySettingsView: View {
    @Environment(AppController.self) private var app
    @State private var selection = Set<UUID>()
    @State private var search = ""
    @State private var editing: GlossaryEntry?
    @State private var isAdding = false
    @State private var showingStarterTerms = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppString.Glossary.intro)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField(AppString.Glossary.search, text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Spacer()
                Button(AppString.Glossary.starterTerms) { showingStarterTerms = true }
                Button(AppString.Glossary.importButton, action: importEntries)
                Button(AppString.Glossary.exportButton, action: exportEntries)
                    .disabled(app.glossary.entries.isEmpty)
            }

            Table(filtered, selection: $selection) {
                TableColumn(AppString.Glossary.preferredColumn) { entry in
                    Text(entry.preferredOutput)
                        .fontWeight(.medium)
                }
                .width(min: 120, ideal: 160)
                TableColumn(AppString.Glossary.aliasesColumn) { entry in
                    Text(entry.aliases.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                        .help(entry.aliases.joined(separator: "\n"))
                }
                TableColumn(AppString.Glossary.modeColumn) { entry in
                    Text(AppString.Glossary.modeName(entry.mode))
                        .foregroundStyle(entry.mode == .disabled ? .tertiary : .primary)
                }
                .width(min: 110, ideal: 140)
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                Button(AppString.Glossary.edit) { edit(ids.first) }
                    .disabled(ids.count != 1)
                Button(AppString.Glossary.delete, role: .destructive) { app.glossary.delete(ids) }
            } primaryAction: { ids in
                edit(ids.first)
            }
            .frame(minHeight: 180)

            HStack(spacing: 6) {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
                .help(AppString.Glossary.add)
                Button {
                    app.glossary.delete(selection)
                    selection.removeAll()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty)
                .help(AppString.Glossary.delete)
                Button(AppString.Glossary.edit) { edit(selection.first) }
                    .disabled(selection.count != 1)
                Spacer()
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = app.glossary.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .buttonStyle(.bordered)

            Toggle(isOn: soundAlikes) {
                Text(AppString.Glossary.soundAlikes)
                Text(AppString.Glossary.soundAlikesHelp)
            }

            GlossaryTryItView()
        }
        .padding(16)
        .sheet(item: $editing) { entry in
            GlossaryEntryEditor(entry: entry) { saved in
                app.glossary.save(saved)
            }
        }
        .sheet(isPresented: $isAdding) {
            GlossaryEntryEditor(entry: nil) { saved in
                app.glossary.save(saved)
            }
        }
        .sheet(isPresented: $showingStarterTerms) {
            StarterTermsSheet { mode in
                message = app.glossary.importEntries(app.glossary.starterEntries(mode: mode))
            }
        }
    }

    private var soundAlikes: Binding<Bool> {
        Binding {
            app.settings.suggestSoundAlikes
        } set: { newValue in
            app.settings.suggestSoundAlikes = newValue
        }
    }

    private var filtered: [GlossaryEntry] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return app.glossary.entries }
        return app.glossary.entries.filter { entry in
            entry.preferredOutput.localizedCaseInsensitiveContains(query)
                || entry.aliases.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func edit(_ id: UUID?) {
        guard let id else { return }
        editing = app.glossary.entries.first { $0.id == id }
    }

    private func importEntries() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        message = app.glossary.importEntries(from: url)
    }

    private func exportEntries() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Krasip Glossary.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try app.glossary.export(to: url)
            message = AppString.Glossary.exported(app.glossary.entries.count)
        } catch {
            message = error.localizedDescription
        }
    }
}
