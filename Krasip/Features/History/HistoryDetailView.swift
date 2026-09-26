// HistoryDetailView.swift
// Krasip
// One dictation: edit the final text, turn transcript spans into preferred spellings, undo changes, retry audio.

import AppKit
import SwiftUI
import KrasipCore

struct HistoryDetailView: View {
    @Environment(AppController.self) private var app
    let record: DictationRecord

    @State private var draft = ""
    @State private var rawSelection = ""
    @State private var corrections: [Correction] = []
    @State private var lastSuggestions: [Suggestion] = []
    @State private var spellingDraft: SpellingDraft?
    @State private var retry: FinalText?
    @State private var isRetrying = false
    @State private var retryError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                finalTextSection
                rawSection
                if !record.changes.filter({ !$0.isCosmetic }).isEmpty {
                    changesSection
                }
                if !corrections.isEmpty {
                    correctionsSection
                }
                if record.audioPath != nil {
                    audioSection
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .toolbar {
            ToolbarItemGroup {
                Button(AppString.History.copy, systemImage: "doc.on.doc") {
                    app.inserter.copyToClipboard(record.finalText)
                }
                Button(AppString.History.delete, systemImage: "trash", role: .destructive) {
                    app.history.delete(record.id)
                }
            }
        }
        .onAppear(perform: load)
        .sheet(item: $spellingDraft) { draft in
            PreferredSpellingSheet(draft: draft, record: record) {
                load()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.startedAt, format: .dateTime.weekday(.wide).day().month().year().hour().minute())
                .font(.title3.weight(.semibold))
            HStack(spacing: 14) {
                if let app = record.destinationAppName {
                    Label(app, systemImage: "app")
                }
                Label(AppString.History.engine(record.providerID), systemImage: "waveform")
                if let confidence = record.confidence {
                    Label(confidence.formatted(.percent.precision(.fractionLength(0))), systemImage: "gauge.with.dots.needle.33percent")
                        .help(AppString.History.confidenceHelp)
                }
                if let latency = record.latency {
                    Label(String(format: "%.1fs", latency), systemImage: "timer")
                        .help(AppString.History.latencyHelp)
                }
                if let insertion = record.insertion {
                    Label(AppString.History.insertionName(insertion), systemImage: insertion.succeeded ? "checkmark.circle" : "doc.on.clipboard")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var finalTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppString.History.finalText)
                .font(.headline)
            TextEditor(text: $draft)
                .font(.system(size: 15))
                .frame(minHeight: 80, maxHeight: 180)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
            HStack {
                Button(AppString.History.saveCorrection, action: saveCorrection)
                    .buttonStyle(.borderedProminent)
                    .disabled(draft == record.finalText || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(AppString.History.revert) { draft = record.finalText }
                    .disabled(draft == record.finalText)
                Spacer()
                if record.policyText != record.finalText {
                    Button(AppString.History.restorePolicyText) { draft = record.policyText }
                        .buttonStyle(.borderless)
                }
            }
            Text(AppString.History.correctionHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(lastSuggestions) { suggestion in
                SuggestionLine(suggestion: suggestion) {
                    spellingDraft = SpellingDraft(alias: suggestion.alias, preferredOutput: suggestion.preferredOutput, correctionID: corrections.last?.id)
                }
            }
        }
    }

    private var rawSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppString.History.rawTranscript)
                    .font(.headline)
                Spacer()
                Button(AppString.History.addPreferredSpelling) {
                    spellingDraft = SpellingDraft(alias: rawSelection, preferredOutput: "", correctionID: nil)
                }
                .disabled(rawSelection.isEmpty)
                .help(AppString.History.addPreferredSpellingHelp)
            }
            SelectableTextView(text: record.rawText, selection: $rawSelection)
                .frame(minHeight: 60, maxHeight: 120)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            Text(AppString.History.rawHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppString.History.changes)
                .font(.headline)
            ChangeList(changes: record.changes.filter { !$0.isCosmetic }) { change in
                undo(change)
            }
        }
    }

    private var correctionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppString.History.corrections)
                .font(.headline)
            ForEach(corrections) { correction in
                CorrectionRow(correction: correction) { suggestion in
                    spellingDraft = SpellingDraft(alias: suggestion.alias, preferredOutput: suggestion.preferredOutput, correctionID: correction.id)
                }
            }
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppString.History.audio)
                .font(.headline)
            HStack {
                Button(AppString.History.play, systemImage: "play.fill") {
                    if let path = record.audioPath {
                        NSSound(contentsOf: URL(fileURLWithPath: path), byReference: true)?.play()
                    }
                }
                .disabled(!app.audioArchive.exists(path: record.audioPath))
                Button(AppString.History.retry, systemImage: "arrow.clockwise", action: retranscribe)
                    .disabled(isRetrying || !app.audioArchive.exists(path: record.audioPath))
                if isRetrying {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if let retryError {
                Text(retryError)
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            if let retry {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppString.History.retryResult)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(retry.text)
                        .textSelection(.enabled)
                    Button(AppString.History.useRetry) {
                        draft = retry.text
                        saveCorrection()
                    }
                    .disabled(retry.text == record.finalText)
                }
                .padding(10)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Actions

    private func load() {
        draft = record.finalText
        corrections = app.history.corrections(for: record.id)
    }

    private func saveCorrection() {
        let outcome = app.history.applyCorrection(id: record.id, text: draft)
        lastSuggestions = (outcome?.suggestions ?? []).filter { !app.glossary.glossary.alreadyKnows($0) }
        corrections = app.history.corrections(for: record.id)
    }

    /// Re-runs the text policy on the raw transcript without this change, and saves the result as a correction.
    private func undo(_ change: TextChange) {
        var decisions = PolicyDecisions()
        decisions.undo(change)
        let text = TextPolicy().finalize(
            record.rawText,
            glossary: app.glossary.glossary,
            style: app.style(forApp: record.destinationBundleID),
            decisions: decisions
        ).text
        draft = text
        saveCorrection()
    }

    private func retranscribe() {
        isRetrying = true
        retryError = nil
        Task {
            do {
                retry = try await app.retranscribe(record)
            } catch {
                retryError = error.localizedDescription
            }
            isRetrying = false
        }
    }
}

/// Alias and spelling to prefill in the "Add preferred spelling" sheet.
struct SpellingDraft: Identifiable {
    let id = UUID()
    var alias: String
    var preferredOutput: String
    var correctionID: UUID?
}
